# 手机安装测试版

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
