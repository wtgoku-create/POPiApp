# GitHub Actions

## 提交前校验

项目使用 Lefthook 管理 Git 提交钩子。首次配置前，请安装 Lefthook 并在项目根目录执行：

```bash
brew install lefthook
lefthook install
```

之后每次提交前会自动执行：

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

任一步骤失败，提交会被阻止。格式检查失败时先执行 `dart format lib test`，再重新提交。

`flutter.yml` 提供校验、构建和上传任务：

- `verify`：Push 和 Pull Request 都会执行格式检查、`flutter analyze` 和 `flutter test`。
- `build-android`：在推送 `v` 开头的 Tag（例如 `v1.0.0`）或手动勾选时读取 Android 签名 Secrets，构建 signed release APK 并上传为 Artifact，适合直接安装或通过其他渠道分发。
- `build-ios`：在推送 `v` 开头的 Tag（例如 `v1.0.0`）或手动运行时，使用 GitHub 的 macOS runner 读取签名 Secrets，按 App Store Connect 发布方式构建 iPhone/iPad 的签名 IPA，并上传 IPA Artifact。
- `upload-ios-testflight`：独立的 TestFlight 上传节点。Tag 发布会自动执行；手动运行时只有同时勾选 `Build iOS IPA` 和 `Upload iOS IPA to TestFlight` 才会执行。

## 手动打包

1. 打开 GitHub 仓库的 **Actions** 页面。
2. 选择 **Flutter CI and Android Build**。
3. 点击 **Run workflow**。
4. 使用复选框选择 `Build Android APK`、`Build iOS IPA`，可以单独打包 APK、IPA，也可以同时勾选。
5. 只有需要上传 TestFlight 时，才勾选 `Upload iOS IPA to TestFlight`。
6. 完成后在任务的 **Artifacts** 区域下载 `popi-app-android-apk-signed` 或 `flutter-starter-ios-signed`。

## 签名发布

Android Job 需要在 GitHub 仓库的 **Settings → Secrets and variables → Actions → Secrets** 中配置：

- `ANDROID_KEYSTORE_BASE64`：Android Keystore/JKS 文件转 Base64
- `ANDROID_KEYSTORE_PASSWORD`：Keystore 密码
- `ANDROID_KEY_ALIAS`：Key alias
- `ANDROID_KEY_PASSWORD`：Key 密码

当前 Android 包名为：

```text
com.popiai.app
```

Android 发布构建产物为：

```text
build/app/outputs/flutter-apk/app-release.apk
```

你不上架 Google Play 时，可以直接分发签名 APK。`upload-keystore.jks` 是 Android 签名密钥，后续更新必须继续使用同一把密钥，务必妥善备份，不能提交到仓库。

Workflow 会临时生成 `android/key.properties` 和 `android/upload-keystore.jks`，构建完成后随 runner 销毁。不要把 Keystore、密码或 `key.properties` 提交到仓库。

iOS Job 构建的是签名 IPA，目标平台是 iPhone/iPad，不是 macOS。需要在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中配置：


- `IOS_CERTIFICATE_BASE64`：Apple Distribution `.p12` 文件转 Base64
- `IOS_CERTIFICATE_PASSWORD`：`.p12` 文件密码
- `IOS_PROVISIONING_PROFILE_BASE64`：与 Bundle ID 和证书匹配的 `.mobileprovision` 转 Base64
- `IOS_PROVISIONING_PROFILE_NAME`：Provisioning Profile 的 Name
- `IOS_TEAM_ID`：Apple Developer Team ID
- `IOS_BUNDLE_ID`：Apple Developer 中注册的 App Bundle ID

TestFlight 自动上传还需要在同一页面配置 App Store Connect API Secrets：

- `APPSTORE_ISSUER_ID`：App Store Connect API 的 Issuer ID
- `APPSTORE_KEY_ID`：App Store Connect API Key ID
- `APPSTORE_PRIVATE_KEY`：下载的 `.p8` 私钥完整内容，包含 `BEGIN PRIVATE KEY` 和 `END PRIVATE KEY`

CI 会将 `IOS_BUNDLE_ID` 替换工程中的默认 `com.example.flutterStarter` 占位值。

示例转换命令：

```bash
base64 -i distribution.p12 | pbcopy
base64 -i Runner.mobileprovision | pbcopy
```

当前 iOS Workflow 使用 `app-store` 导出方式。构建节点负责生成 IPA 并上传 GitHub Artifact；TestFlight 上传是独立节点。手动运行不勾选 `Upload iOS IPA to TestFlight` 时不会上传 TestFlight。不要把证书、Profile、密码或 API 私钥提交到仓库。
