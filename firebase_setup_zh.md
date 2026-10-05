# Firebase 配置清单（daily_english 接入 simple_feedback）

> 需要全程开代理（Firebase 控制台在大陆被墙）。

## 1. 建 Firebase 项目

1. 打开 <https://console.firebase.google.com> → 添加项目（如 `daily-english`）。
2. Analytics 可不开（省事）。

## 2. 注册 App 并下载配置文件

- iOS：项目设置 → 你的应用 → 添加 iOS 应用，bundle id 用 daily_english 当前的
  （`ios/Runner.xcodeproj` 里 `PRODUCT_BUNDLE_IDENTIFIER`，可用
  `grep PRODUCT_BUNDLE_IDENTIFIER -m1 ios/Runner.xcodeproj/project.pbxproj` 查）。
  下载 `GoogleService-Info.plist` → 放到 `ios/Runner/`（Xcode 里 Add Files 拖进
  Runner target，或直接放目录后重新 pod install）。
- Android（如果还发安卓）：添加 Android 应用 → 下载 `google-services.json` →
  放到 `android/app/`，并在 `android/build.gradle` 加 classpath
  `com.google.gms:google-services:4.4.x`、`android/app/build.gradle` 末尾加
  `apply plugin: 'com.google.gms.google-services'`（仅 Android 需要，iOS 不用）。

## 3. Firestore

1. 左侧 Build → Firestore Database → 创建数据库（生产模式，选区域如
   `asia-east1` 或 `us-central1`）。
2. 规则（Build → Firestore Database → Rules）替换为：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /feedback/{doc} {
      allow create: if true;
      allow read, update, delete: if false;
    }
  }
}
```

3. 发布。

## 4. Storage（截图上传用）

1. Build → Storage → 开始使用（会自动建默认 bucket，跟 Firestore 同区域）。
2. 规则替换为：

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /feedback/{allPaths=**} {
      allow read: if false;
      allow create: if request.resource.size < 10 * 1024 * 1024
                    && request.resource.contentType.matches('image/.*');
    }
  }
}
```

3. 发布。

## 5. 验证

1. 重新构建运行 daily_english（放好 plist 后首次 build 会装 Firebase 的
   pod，时间长一点）。
2. 设置页 → 反馈问题：弹窗应正常弹出；填内容提交。
3. Firestore 控制台 → feedback 集合应出现一条记录（含 type/content/source/
   deviceId/platform/appVersion/createdAt）；如带截图，Storage 的
   `feedback/<deviceId>/` 下应有图片。
4. 日文界面语言下打开弹窗，文案应为日文。

## 常见问题

- **弹窗报"提交失败"**：多为 Firebase 未初始化（plist 没放/没生效）、
  Firestore 规则没发布、或设备没代理（大陆网络访问不了 Firestore）。
- **看数据**：Firestore 控制台的 feedback 集合；图片在 Storage。
- **升级到 App Check 防 spam**（可选，后续再说）：控制台 App Check →
  注册 App（iOS 用 DeviceCheck）→ 按提示开启强制。
