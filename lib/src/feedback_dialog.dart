import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import 'feedback_config.dart';
import 'feedback_device_id.dart';
import 'feedback_service.dart';
import 'feedback_strings.dart';
import 'feedback_type.dart';

/// Opens the feedback dialog.
///
/// [source] is recorded with the submission (e.g. the page name the button
/// sits on). [metadata] is written to the Firestore document as-is — use it
/// for app version, user id, experiment flags, etc. [screenshotKey] is the
/// [GlobalKey] of a [RepaintBoundary] wrapping the current page; when given,
/// the page is captured as the first screenshot before the dialog opens.
///
/// Uses the global [SimpleFeedback.config] unless [config] is passed.
Future<void> showSimpleFeedback(
  BuildContext context, {
  required String source,
  String? sourceData,
  Map<String, dynamic>? metadata,
  GlobalKey? screenshotKey,
  SimpleFeedbackConfig? config,
}) async {
  final cfg = config ?? SimpleFeedback.config;

  Uint8List? screenshot;
  if (screenshotKey != null) {
    screenshot = await captureBoundary(screenshotKey, context);
  }

  if (!context.mounted) return;

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: _FeedbackModal(
        source: source,
        sourceData: sourceData,
        metadata: metadata,
        screenshotKey: screenshotKey,
        initialScreenshots:
            screenshot != null ? <Uint8List>[screenshot] : const [],
        config: cfg,
      ),
    ),
  );
}

/// Captures the [RepaintBoundary] behind [key] as PNG bytes.
///
/// Uses the device pixel ratio for crisp output. Returns `null` on any
/// failure (key not mounted, wrong widget type, ...) — callers treat a failed
/// capture as "no screenshot", never as an error.
Future<Uint8List?> captureBoundary(GlobalKey key, BuildContext context) async {
  try {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Palette used by the dialog: [ColorScheme] roles with the host's
/// [FeedbackColors] overrides applied.
class _Palette {
  _Palette.of(BuildContext context, FeedbackColors? overrides)
      : surface = overrides?.surface ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        surfaceLow = overrides?.surfaceLow ?? Theme.of(context).colorScheme.surfaceContainerLow,
        onSurface = overrides?.onSurface ?? Theme.of(context).colorScheme.onSurface,
        onSurfaceVariant =
            overrides?.onSurfaceVariant ?? Theme.of(context).colorScheme.onSurfaceVariant,
        primary = overrides?.primary ?? Theme.of(context).colorScheme.primary,
        primaryContainer =
            overrides?.primaryContainer ?? Theme.of(context).colorScheme.primaryContainer,
        onPrimary = overrides?.onPrimary ?? Theme.of(context).colorScheme.onPrimary,
        outlineVariant = overrides?.outlineVariant ?? Theme.of(context).colorScheme.outlineVariant,
        error = overrides?.error ?? Theme.of(context).colorScheme.errorContainer;

  final Color surface;
  final Color surfaceLow;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;
  final Color outlineVariant;
  final Color error;
}

FeedbackStrings _resolveStrings(BuildContext context, SimpleFeedbackConfig config) {
  final override = config.strings;
  if (override != null) return override;
  final locale = Localizations.maybeLocaleOf(context) ??
      View.of(context).platformDispatcher.locale;
  return FeedbackStrings.builtin(locale);
}

class _FeedbackModal extends StatefulWidget {
  final String source;

  /// Read-only context submitted as the `sourceData` field, kept strictly
  /// separate from the user-typed content.
  final String? sourceData;

  /// Extra fields merged into the Firestore document as-is.
  final Map<String, dynamic>? metadata;

  /// Caller's [RepaintBoundary] key; enables the "capture current page"
  /// option. `null` = gallery only.
  final GlobalKey? screenshotKey;

  /// Screenshots already taken when the dialog opens (page capture).
  final List<Uint8List> initialScreenshots;

  final SimpleFeedbackConfig config;

  const _FeedbackModal({
    required this.source,
    this.sourceData,
    this.metadata,
    this.screenshotKey,
    this.initialScreenshots = const [],
    required this.config,
  });

  @override
  State<_FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<_FeedbackModal>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  FeedbackType _selectedType = FeedbackType.suggestion;
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  /// Expansion state of the read-only context block (collapsed by default).
  bool _sourceExpanded = false;

  /// Pending screenshots (page captures and gallery picks alike), uploaded
  /// on submit.
  final List<Uint8List> _images = [];

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.initialScreenshots);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = widget.config.service ??
          FeedbackService(firebaseApp: widget.config.firebaseApp);
      final deviceId = await FeedbackDeviceId.get();
      await service.submit(
        type: _selectedType,
        content: content,
        source: widget.source,
        deviceId: deviceId,
        sourceData: widget.sourceData,
        metadata: widget.metadata,
        images: _images,
        collection: widget.config.collection,
        storagePrefix: widget.config.storagePrefix,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context);
      }
    } on FeedbackUploadException {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnack(_resolveStrings(context, widget.config).errorUpload);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnack(_resolveStrings(context, widget.config).errorSubmit);
      }
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _Palette.of(context, widget.config.colors).error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// "Capture current page / pick from gallery" bottom sheet. The capture
  /// option is hidden when no [screenshotKey] was provided.
  void _showAddImageSheet() {
    final palette = _Palette.of(context, widget.config.colors);
    final strings = _resolveStrings(context, widget.config);
    if (_images.length >= widget.config.maxImages) {
      _showErrorSnack(strings.errorTooManyImages(widget.config.maxImages));
      return;
    }
    final canScreenshot = widget.screenshotKey != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  strings.addScreenshotTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.onSurfaceVariant,
                      ),
                ),
              ),
              if (canScreenshot)
                ListTile(
                  leading: Icon(Icons.screenshot_monitor_outlined,
                      color: palette.onSurface, size: 22),
                  title: Text(strings.captureCurrentPage,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: palette.onSurface)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _captureCurrentPage();
                  },
                ),
              ListTile(
                leading:
                    Icon(Icons.photo_outlined, color: palette.onSurface, size: 22),
                title: Text(strings.pickFromGallery,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: palette.onSurface)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureCurrentPage() async {
    final key = widget.screenshotKey;
    if (key == null) return;
    final bytes = await captureBoundary(key, context);
    if (!mounted) return;
    if (bytes == null) {
      _showErrorSnack(_resolveStrings(context, widget.config).errorCapture);
      return;
    }
    _addImage(bytes);
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      _addImage(bytes);
    } catch (_) {
      if (mounted) {
        _showErrorSnack(_resolveStrings(context, widget.config).errorPick);
      }
    }
  }

  void _addImage(Uint8List bytes) {
    if (_images.length >= widget.config.maxImages) {
      _showErrorSnack(
          _resolveStrings(context, widget.config)
              .errorTooManyImages(widget.config.maxImages));
      return;
    }
    setState(() => _images.add(bytes));
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  // ── Source data (read-only collapse) ──────────────────────────────────

  Widget _buildSourceDataSection(_Palette palette, FeedbackStrings strings) {
    final source = widget.sourceData!.trim();
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _sourceExpanded = !_sourceExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15,
                      color: palette.onSurfaceVariant.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      strings.sourceDataTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: palette.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    strings.readOnly,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _sourceExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right,
                        size: 18,
                        color: palette.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _sourceExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: palette.outlineVariant.withValues(alpha: 0.2)),
                ),
              ),
              child: SelectableText(
                source,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      color: palette.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Screenshots ───────────────────────────────────────────────────────

  Widget _buildImagesSection(_Palette palette, FeedbackStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              strings.screenshotsLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: palette.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                strings.screenshotsHint(widget.config.maxImages),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _images.length; i++) _imageThumb(palette, i),
            if (_images.length < widget.config.maxImages) _addButton(palette),
          ],
        ),
      ],
    );
  }

  Widget _imageThumb(_Palette palette, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _images[index],
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: GestureDetector(
            onTap: _isSubmitting ? null : () => _removeImageAt(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addButton(_Palette palette) {
    return GestureDetector(
      onTap: _isSubmitting ? null : _showAddImageSheet,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: palette.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: palette.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            color: palette.onSurfaceVariant, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context, widget.config.colors);
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSubmitted ? _buildSuccess(context) : _buildForm(context),
        ),
      ),
    );
  }

  // ── Success state ─────────────────────────────────────────────────────

  Widget _buildSuccess(BuildContext context) {
    final palette = _Palette.of(context, widget.config.colors);
    final strings = _resolveStrings(context, widget.config);
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  palette.primary.withValues(alpha: 0.2),
                  palette.primaryContainer.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: Icon(Icons.check_rounded, color: palette.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            strings.successTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: palette.onSurface,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.successSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Form state ────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context) {
    final palette = _Palette.of(context, widget.config.colors);
    final strings = _resolveStrings(context, widget.config);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      key: const ValueKey('form'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    strings.title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.onSurface,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.surfaceLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        color: palette.onSurfaceVariant, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.subtitle,
              style: textTheme.bodyMedium
                  ?.copyWith(color: palette.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // ── Type selection ──
            Text(
              strings.typeLabel,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: palette.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: FeedbackType.values.map((type) {
                final isSelected = _selectedType == type;
                final label = switch (type) {
                  FeedbackType.bug => strings.typeBug,
                  FeedbackType.suggestion => strings.typeSuggestion,
                  FeedbackType.other => strings.typeOther,
                };
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.only(
                        right: type != FeedbackType.other ? 10 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.primary.withValues(alpha: 0.15)
                            : palette.surfaceLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? palette.primary.withValues(alpha: 0.5)
                              : palette.outlineVariant.withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(type.emoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? palette.primary
                                  : palette.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Content input ──
            Text(
              strings.contentLabel,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: palette.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: palette.surfaceLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: palette.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 4,
                maxLength: widget.config.maxContentLength,
                style: textTheme.bodyLarge?.copyWith(
                  color: palette.onSurface,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: strings.contentHint,
                  hintStyle: textTheme.bodyLarge?.copyWith(
                    color: palette.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: textTheme.labelSmall?.copyWith(
                    color: palette.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Source data (read-only) ──
            if ((widget.sourceData?.trim().isNotEmpty ?? false))
              _buildSourceDataSection(palette, strings),
            const SizedBox(height: 12),

            // ── Screenshots ──
            _buildImagesSection(palette, strings),
            const SizedBox(height: 20),

            // ── Page tag ──
            Row(
              children: [
                Icon(Icons.article_outlined,
                    size: 14,
                    color: palette.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${strings.pageLabelPrefix}: ${widget.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Submit ──
            GestureDetector(
              onTap: _isSubmitting ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSubmitting
                        ? [palette.surfaceLow, palette.surfaceLow]
                        : [palette.primaryContainer, palette.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isSubmitting
                      ? []
                      : [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: palette.onSurfaceVariant,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          strings.submit,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
