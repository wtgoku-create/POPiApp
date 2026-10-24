# 手机安装测试版

## 2026-10-24 启动退出现场诊断

通过已配对真机的实时日志确认，安装版本为 `1.0.0 (4701)`。重复启动均在约两秒后退出，
系统明确记录 `jetsam / per-process-limit`：进程实际占用 `3,457,028 KB`，超过 `3376 MiB`
硬上限。已确认内存超限终止，但尚未定位具体分配来源，不能将 4701 描述为已修复。

原生启动诊断只在启动后的 15 秒采样进程内存，并记录固定的引擎、插件、Dart、登录恢复、
Repository 和首帧检查点。记录限于设备本地系统日志，不写用户内容、账号、路径、请求或 Token，
也不上传日志。原始设备日志仅保存在忽略的 `.omx/state/iphone-crash-4701-launch/` 中。
诊断通道不可用或无响应时不阻塞启动；Web、Android 和 macOS 不发送该通道消息。

## iPhone 4701 兼容性复测

[GitHub Release：1.0.0（4701）](https://github.com/wtgoku-create/POPiApp/releases/tag/ios-harness-1.0.0-4701)
用于复测 4201 登录成功后或进入会话时退出的问题。 Apple 已确认 4701 为 `IN_BETA_TESTING`，已加入内部测试的用户可在 TestFlight 更新。

- iOS 原生端跳过自定义组合 shader 的预加载和创建，复用现有普通模糊与渐变。
- 远程缩略图按已有 `cacheWidth` 限制解码内存，保留原图预览与原有鉴权、缓存命名空间。
- 本机与 CI 均通过 1,874 项测试；IPA 签名、版本、SHA-256 和原生 dSYM UUID 已核验。
- Apple 确认 4201 的既有声明为 `usesNonExemptEncryption=false`；4701 沿用该声明，SDK 与依赖锁未变。
- 本次未取得设备原生崩溃栈，不能将兼容性处理描述为已确认所有闪退根因。Apple crash-feedback 为零，也不等于未发生崩溃。

更新后重点复测打开 App、登录、进入已有会话、滚动及图片预览。若仍退出，需要对应时刻的
`.ips` 设备分析日志，以及 iPhone 型号和 iOS 版本。精确的符号文件保存在构建记录中。
完整证据位于 `.omx/state/iphone-crash-4201/verification.json`。

## 2026-10-24 交付记录

- 版本：`1.0.0 (4201)`，代码快照 `07b2f0ff719cb843a426f8a64082bc221ef2a412`。
- Android 安装包：<https://124.222.185.31/downloads/POPi-android-1.0.0-4201-c6f35ff35a18.apk>，约 256 MiB，Android 7.0 及以上。
- 本机和签名 CI 均通过 1,872 项测试；Android/iOS 签名与版本校验通过。
- Android 公网下载、文件摘要、HEAD、Range 和未公开路径 404 已验证，尚待同事手机实机验收。
- iOS 同版本初次上传时状态为 `MISSING_EXPORT_COMPLIANCE`；截至 08:07 UTC，Apple 已确认 `IN_BETA_TESTING`，可内部测试。账号仍没有外部测试组或公开邀请链接。
- 外部同事测试还需 Apple ID 和测试组配置；加密声明应依据实际 SDK 与已有确认记录，不能仅为消除提示而盲填。
- 原生登录、素材鉴权和打包复用已有网关、Secure Storage、媒体组件与签名流程，未新增依赖或将固定密码写入包内。

完整构建和下载验证保存在 `.omx/state/mobile-package/verification.json`。登录密码仅在独立私密交付文件中保管，不写入本文。

## Android：直接安装 APK

远程 Harness 测试包由 GitHub Actions 使用正式 Android 签名配置构建。CI 会先用
`apksigner` 验证签名，再用 `aapt` 核对包名、版本号、构建号和 `minSdk`。只有验证通过
后才生成公开 metadata；服务器发布脚本还会复核以下内容：

- `applicationId` 必须是 `com.popistudio.app`；
- 环境必须是 `harness_remote`，入口必须是 `lib/main_harness.dart`；
- `signatureVerified` 必须为 `true`，`minSdk` 必须为 `24`；
- APK 的 SHA-256 必须与 metadata 一致；
- metadata 只能包含允许公开的构建字段，不能夹带密码、Token 或服务端配置。

从 CI 下载 `popi-app-android-apk-signed-harness` 和
`popi-app-android-build-metadata-harness` 两个 artifact，解压后将 APK、JSON 和发布脚本
传到测试服务器的临时目录。然后在服务器执行：

```sh
python3 publish-mobile.py app-release.apk android-harness.json
```

脚本输出 APK 的 HTTPS 地址和 SHA-256。把该 APK 地址发给同事，在 Android 手机浏览器
中打开并下载；系统首次侧载时会要求允许浏览器“安装未知应用”。更新测试版时可直接安装
新 APK，包名和签名相同会覆盖旧版本并保留应用数据。

发布只允许当前 APK 和对应 JSON 的两个精确 `/downloads/` 路径。目录、旧文件名和其他
任意文件都返回 `404`。脚本先校验候选 Caddy 配置，再备份 POPi 的独立站点配置，最后
reload；校验或 reload 失败会恢复原配置和原站点，不改写主 Caddyfile 中的其他域名。
相同 APK 重复运行是幂等的。

安装包不包含测试账号密码。首次打开原生 App 后，在登录页输入测试服务器账号；成功后
登录会话保存在手机安全存储中，图片、视频、音频和 API 请求使用同一会话。测试密码应通过
团队的私密渠道发送，不要放进下载 URL、metadata、安装包或公开文档。

## iPhone：通过 TestFlight

iOS 的 App Store 分发 IPA 不能像 Android APK 一样从网页直接安装。CI 构建并上传
TestFlight 后，需要在 App Store Connect 中把同事加入测试组，或使用已启用的公开
TestFlight 链接。同事先安装 Apple 的 TestFlight，再从邀请或链接安装 POPi 测试版。

不要把 App Store IPA 放到 `/downloads/` 并宣称可直接安装。网页安装 iOS App 需要另一套
企业或 Ad Hoc 签名、设备登记和 manifest，本项目当前的同事测试流程统一走 TestFlight。

## 发布后核对

在不输出测试密码或 Cookie 的前提下，至少核对：

```sh
curl -fsS -o /dev/null -w '%{http_code}\n' 'https://124.222.185.31/downloads/<APK 文件名>'
curl -fsS -o /dev/null -w '%{http_code}\n' 'https://124.222.185.31/downloads/<metadata 文件名>'
curl -sS -o /dev/null -w '%{http_code}\n' 'https://124.222.185.31/downloads/'
curl -sS -o /dev/null -w '%{http_code}\n' 'https://124.222.185.31/downloads/not-published.apk'
```

前两个请求应为 `200`，后两个应为 `404`。再在一台未登录的 Android 手机上完成下载、
安装、登录、发一条文字消息，并打开一项图片或视频素材。无需触发付费媒体生成。
