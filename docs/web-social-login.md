# Web 社交登录

`LoginPage` 仅在 `kIsWeb` 下使用 website 的登录接口。iOS、Android 和其他原生端继续使用原有微信、抖音 SDK 授权及 App 登录接口。

| 场景 | 接口 |
| --- | --- |
| 获取微信二维码 | `GET /api_client/auth/wxghQrCode` |
| 查询微信扫码结果 | `GET /api_client/auth/checkWxghLogin?sceneCode=...` |
| 微信首次登录绑定手机号 | `POST /api_client/auth/wxghRegisterByPhone` |
| 获取抖音授权地址 | `GET /api_client/auth/douyinQrCode` |
| 查询抖音授权结果 | `GET /api_client/auth/checkDouyinLogin?state=...` |
| 抖音首次登录绑定手机号 | `POST /api_client/auth/douyinRegisterByPhone` |

微信二维码直接展示服务端返回的图片。抖音从点击事件同步打开独立授权窗口，再加载服务端返回的官方授权地址；原页面通过 state 查询结果。这样可以使用现有 website 域名下的服务端回调。浏览器需要允许授权窗口弹出；取消、过期、完成登录或进入手机号绑定时关闭该窗口。

轮询按请求完成后间隔两秒串行执行，返回、刷新授权或页面销毁会取消旧请求并忽略迟到结果。授权有效期使用 `expireSeconds`，未返回时使用五分钟。接口失败通过 AppToast 提示，保留原有刷新入口；二维码过期后隐藏旧二维码。

首次登录的 `needBindPhone` 和 `registerToken` 进入现有手机号绑定页面，短信和滑块验证码复用原流程。抖音未完成的 state、有效期和绑定阶段通过 PreferencesStorage 保存，支持刷新恢复；完成或主动取消后清除。兼容 `douyin_callback=1&douyin_state=...` 回调，只有与本地记录一致且未过期的 state 才继续处理。

业务 Web 环境继续复用现有 HttpOnly Cookie 登录机制，不新增业务 Bearer 存储。部署时保留 `/api_client/` 的同源代理，确保查询登录结果和手机号绑定接口设置的 Cookie 属于当前应用来源。第三方实际授权和 Cookie 行为需要在目标部署域名完成联调。

## 已登录账号绑定

Web 个人页不显示抖音绑定入口，抖音扫码登录和移动 App 绑定保持可用。
微信使用 `/api_client/users/user/` 下的 `wxghBindStatus`、`wxghBindQrCode`
和 `checkWxghBind`，通过扫码弹窗绑定当前账号，不调用登录接口或替换登录 Token。
关闭、刷新、过期和切换账号会取消轮询；昵称刷新失败不会撤销已完成的绑定。

验证命令：

```bash
flutter pub get
flutter analyze
flutter test
flutter test --platform chrome test/web_social_auth_test.dart test/web_social_login_page_test.dart
flutter test --platform chrome test/web_social_binding_test.dart test/social_app_binding_api_test.dart
```
