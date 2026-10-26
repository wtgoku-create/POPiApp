# POPi

一个可扩展的 Flutter 空项目模板，内置：

- Riverpod 状态管理
- go_router 路由
- Dio 网络请求客户端
- SharedPreferences 本地偏好设置
- flutter_secure_storage 安全 Token 存储
- Dio Token 拦截器与统一网络异常
- Auth API / Repository 分层
- 中文/英文国际化
- 系统、浅色、深色主题切换
- 可持久化的用户状态管理
- SVG 图标组件与本地资源目录
- Toast 提示封装

## 使用

本机安装包含 Dart 3.10.1 或更高版本的 Flutter SDK 后，在项目目录执行：

```bash
flutter create .
flutter pub get
dart run tool/flutter_env.dart development run
```

`flutter create .` 会补齐 Android、iOS、Web 等平台目录，不会覆盖 `lib/` 和 `pubspec.yaml`。

## 目录

```text
lib/
├── app/                 # App 入口、路由、主题
├── core/                # 网络层、存储层、基础能力
├── features/            # 按业务拆分的功能模块
│   └── auth/            # 用户模型与数据源
│       ├── data/        # 用户本地数据源
│       └── domain/      # 用户模型
├── l10n/                # ARB 文案与生成的本地化代码
└── shared/
    ├── providers/       # 统一状态管理与共享 Provider
        ├── network_provider.dart
        ├── settings_provider.dart
        ├── storage_provider.dart
        └── user_provider.dart
    └── type/            # 共享类型定义
        └── user_type.dart
```

### V2 页面模块

原有业务模块继续保留，原 `features/demo/` 页面按业务拆分为：

```text
lib/
├── app/v2_app.dart
└── features/
    ├── v2_home/         # 首页、会话列表、新建引导
    ├── v2_session/      # 聊天、会话设置、聊天控制器
    ├── v2_assets/       # 素材列表、音频详情、媒体导出
    └── v2_shared/       # V2 共用组件、模型、本地仓库和样例数据
```

V2 仍通过 `lib/main_demo.dart` 启动，使用本地样例数据；沿用已有存储键和资源。

```bash
dart run tool/flutter_env.dart development run -t lib/main_demo.dart
```

## 网络请求

普通业务接口通过 `dioProvider` 和 `NetworkApi` 调用。开发环境 API 地址为
`https://wwwtest.popi.art`，生产环境为 `https://www.popi.art`。

`/api_agent` 接口通过 `agentDioProvider` 和 `NetworkAgentApi` 调用，使用独立的
服务地址和 Origin，并复用 Token 鉴权。Go 和 PI Host 默认共用测试服或生产域名，
本地调试时可分别指定服务地址；原生 App 默认不发送 Origin，需要时可以配置
后台允许的 Origin。地址变更时修改环境 JSON。Agent 成功响应直接返回 JSON，错误保留 code、retryable、requestId
和 current 等字段。

会话契约按 `popiart-agent-server/src/studio/http/routes.ts` 核对：v2 使用
`page/pageSize` 与 `list/pageInfo`，支持服务端置顶及不带项目过滤的会话列表。
改名使用 PATCH，归档使用 DELETE；重试保留原请求号和完整输入。
消息提交返回运行 ID，事件流通过 `openSessionEvents` 获取原始 SSE 字节，并由数据层
解析。缺省不发送 Origin，显式配置的 Origin 必须在后台 `PUBLIC_ORIGIN` 白名单中。

已同步 Web `feature/agent_bot` 至 `f966a8c` 的接口变更：服务端标记
`runtimeDirect: true` 的会话通过固定 `/runtime/v2/sessions/:id/` 路由调用快照、消息、
停止、问答及执行重试接口，使用 `RUNTIME_API_BASE_URL`，复用可选 Origin 和登录 Bearer Token，
不再请求 `runtime-connection` 或获取短期令牌。网关将 `/runtime` 转发到 PI Host、
`/api_agent` 转发到 Go；移动端无需服务端下发运行地址。Runtime SSE 的 `conversation`
事件携带完整快照，允许游标跳号；普通会话继续使用原来的增量 SSE。

直连生成方案仍通过 Agent 的 `configuration`、`respond` 接口配置和确认，携带
`revision`、`planVersionId`、`planHash` 及媒体偏好版本，不再由客户端另行调用业务授权。
文本产物通过统一 `/api_client/agent/v2/sessions/:id/artifacts?category=text` 分页读取；
未命名会话省略 `title`，角色入口可传 `entry: role`，显式名称继续保留。

## 环境配置

统一配置文件位于 `config/env/development.json` 和 `config/env/production.json`，
Dart 代码只通过 `lib/core/config/app_config.dart` 读取配置。

| 配置项 | 用途 |
| --- | --- |
| `APP_ENV` | 环境名称 |
| `API_BASE_URL` | Go 业务接口根地址，接口路径自身包含 `/api_client` |
| `AGENT_API_BASE_URL` | Go 会话接口根地址，接口路径自身包含 `/api_agent` |
| `RUNTIME_API_BASE_URL` | PI Host 根地址，接口路径自身包含 `/runtime`；未配置时跟随 `AGENT_API_BASE_URL` |
| `AGENT_API_ORIGIN` | Go 会话和 PI Host 共用的可选 Origin，原生 App 可留空；配置值必须在两端白名单中 |
| `API_ENABLE_LOGGING` | Debug 模式网络日志开关 |
| `WECHAT_APP_ID` | 微信开放平台 App ID |
| `WECHAT_UNIVERSAL_LINK` | 微信回调 Universal Link，默认 `https://app.popi.art/WeChat` |
| `DOUYIN_CLIENT_KEY` | 抖音开放平台移动应用 Client Key |
| `DOUYIN_UNIVERSAL_LINK` | 抖音 iOS Universal Link，默认 `https://app.popi.art/Douyin` |
| `USER_AGREEMENT_URL` | 用户协议地址 |
| `PRIVACY_POLICY_URL` | 隐私政策地址 |

```bash
# 开发启动
dart run tool/flutter_env.dart development run

# 生产构建
dart run tool/flutter_env.dart production build apk --release
dart run tool/flutter_env.dart production build ios --release

# 使用指定环境运行测试
dart run tool/flutter_env.dart development test

# 自定义本机配置（*.local.json 不提交 Git）
dart run tool/flutter_env.dart config/env/development.local.json run
```

本地调试对齐 Web 的两套代理目标：`API_BASE_URL`、`AGENT_API_BASE_URL` 对应
Web 的 `DEV_API_TARGET`（Go），`RUNTIME_API_BASE_URL` 对应 `DEV_AGENT_TARGET`
（PI Host），`AGENT_API_ORIGIN` 对应 `DEV_WEB_ORIGIN`。在
`config/env/development.local.json` 中仅覆盖需要变更的字段，例如：

```json
{
  "API_BASE_URL": "http://192.168.1.100:8080",
  "AGENT_API_BASE_URL": "http://192.168.1.100:8080",
  "RUNTIME_API_BASE_URL": "http://192.168.1.100:7801",
  "AGENT_API_ORIGIN": "http://localhost:5195"
}
```

`development` 命令会自动合并同目录的 `development.local.json`；显式传入
`.local.json` 时也会继承同名公共 JSON，其余设置无需复制。以上 IP 是示例，真机应使用
手机可访问的电脑局域网地址；`127.0.0.1` 指向设备自身，Android 模拟器访问宿主机
可用 `10.0.2.2`。默认环境继续使用统一域名，无需本地反向代理。

脚本合并配置后传给 Flutter 原生 `--dart-define-from-file`，并自动生成
`ios/Flutter/Environment.xcconfig`，同步微信 URL Scheme 和 Associated Domains。
新域名仍需在微信开放平台和域名服务器配置对应的 Universal Link/AASA。
支付宝插件的 iOS Universal Link 在 `pubspec.yaml` 的 `tobias.ios.universal_link`
中配置为 `https://app.popi.art/ZhiFuBao`。三个回调地址均不带 `/*`；
AASA 的路径匹配规则独立配置，并应使用当前 Team ID 和 Bundle ID
组成的 `appID`：`84GT698GKX.com.popistudio.app`。开放平台登记的地址需与应用配置一致。
使用 Xcode 启动前先运行：

```bash
dart run tool/flutter_env.dart development prepare
flutter build ios --config-only --dart-define-from-file=config/env/development.json
```

直接运行 `flutter run` 时 Dart 使用开发默认值，iOS 则可能保留上次生成的原生配置；
日常运行和构建应使用上面的脚本。环境配置在构建时生效，切换后需要重新构建。
客户端环境文件只放公开配置，不存放 App Secret、私钥或服务端密钥。

抖音原生授权目前接入 iOS 官方 `DouyinOpenSDK`。环境脚本同步 Client Key、
URL Scheme、Universal Link 和 Associated Domains；`AppDelegate` 和
`SceneDelegate` 将授权回调交给 SDK，Dart 获取一次性 code 后通过现有
`loginByDouyinCode` 接口登录，首次登录继续验证并绑定手机号。
开放平台的移动应用 Bundle ID、Client Key 和 Universal Link 必须与构建一致，
后端换取授权 Token 时也必须使用该移动应用的 Key/Secret。

`DouyinOpenSDK` 4.2.5 没有 arm64 模拟器版本。Pod 安装钩子仅在真机构建中链接
该 SDK，模拟器上的抖音授权返回不可用，其他页面及登录方式可正常调试。
不要为此排除模拟器的 arm64 架构，iOS 26+ 的 Apple Silicon 模拟器需要该架构。

Android 使用官方 `opensdk-china-external` 和 `opensdk-common` 0.2.0.10，
通过同一 MethodChannel 接收环境配置中的 Client Key，仅在用户发起授权时初始化。
`DouyinEntryActivity` 接收 SDK 回调，校验 state 后将授权码交给现有登录接口；
取消、超时和引擎销毁会清理待处理请求。Android 需要安装支持授权的抖音客户端，
开放平台登记的包名 `com.popistudio.app`、APK 签名和 Client Key 必须匹配。
Debug 默认使用本机调试签名，真机登录前需要在平台配置相应签名，或使用已登记的签名打包。

认证相关代码位于 `lib/features/auth/data/`：

- `auth_api.dart`：定义图形验证码、短信验证码、验证码登录和当前用户接口
- `auth_repository.dart`：处理接口异常、Token 保存和登录态初始化
- `lib/core/storage/secure_storage.dart`：安全保存 access token

真实后端接入后，在 `lib/shared/providers/user_provider.dart` 调用
`signIn`，再根据项目的登录页增加路由守卫。

## 移动端支付

支付契约来自[飞书接口文档](https://tcnshqo5yu6i.feishu.cn/wiki/JOJpwV9sGikaF4k6kFScE288nJf)
的「移动端 Android / iOS 支付流程与接口」。请求统一定义在 `NetworkApi`，
支付协调与恢复位于 `lib/features/payments/`。

- Android 使用 standard 套餐和积分包。会员先调用 `previewApp`，显示 `pay_money`
  对应的金额和 `grant_points`；微信、支付宝分别建单，仅发送 `subscriptionId` 或 `packageId`。
- iOS 直接使用 Apple 商品列表的标题、积分和 `amount_fen` 渲染会员、升级和积分包，列表不依赖 StoreKit。购买时再用 `product_id` 查询 StoreKit 商品并确认本地化价格。
  选中后以映射 `id` 请求报价，再使用 `quote_id` 创建购买意图；StoreKit 使用返回的
  `app_account_token`，验单提交完整交易 JWS。会员是固定期限商品，不代表已接入自动续订。
- 只有 `payment_status=paid`、`fulfillment_status=completed`、`refund_status=none`
  同时满足才刷新会员和积分。启动与恢复前台会处理未完成交易；网络异常保留原订单，
  不自动重放 Android 建单，也不自动发起 Apple 支付。Apple 调用中断后，再次点击会先核对
  原订单、未完成交易和匹配的历史交易，再经用户确认继续原订单；明确待确认或待验单的交易
  不会重新发起支付。原生调用超时后保留并发锁，并继续接收迟到的取消或成功结果。

真机联调需要已登录的业务账号。Android 微信开放平台包名、签名和支付 App ID 必须匹配；
iOS 的 Bundle ID、App Store Connect 商品及网关映射必须一致，Sandbox 用户需加入网关允许名单。
使用环境脚本启动以加载对应的 API 基地址和 Apple 环境参数：开发为 `Sandbox`，生产为 `Production`。
自动化测试使用接口和原生 SDK 替身，不会真实扣款。

## 协议 H5 页面

用户协议和隐私政策统一使用 `lib/shared/pages/h5_page.dart` 在 App 内展示，
入口路由分别为 `/legal/user-agreement` 和 `/legal/privacy-policy`。
登录页和充值页的 `LegalDocumentLinks` 已连接到这两个路由。
文档地址继续通过环境配置中的 `USER_AGREEMENT_URL` 和 `PRIVACY_POLICY_URL` 管理。
页面支持加载进度、刷新、失败重试及返回；加载失败时也可在外部浏览器打开。
原生 WebView 支持 Android、iOS 和 macOS，其他平台提供浏览器打开入口。

## Toast

项目使用 `toastification`，业务页面通过 `AppToast` 调用：

```dart
AppToast.success(context, '操作成功');
AppToast.error(context, '操作失败');
AppToast.info(context, '提示信息');
```

封装位置：`lib/shared/widgets/app_toast.dart`。

## 菜单

弹出菜单和二级菜单统一使用 `lib/shared/widgets/app_menu.dart`，外观自动适配
浅色和深色主题：浅色使用白底，菜单外层统一为 20px 大圆角，菜单项为两端半圆的胶囊矩形，
选中与悬停背景为淡灰色。
文案由页面传入国际化字符串，操作在选择后自动关闭整组菜单。
菜单参考苹果系统的排版，使用 44px 最小行高、16px 文案、右侧操作图标和左侧选中勾选。
菜单面板背景不透明，普通菜单展开、收起和状态反馈即时显示，不使用点击波纹。

```dart
AppMenuButton(
  tooltip: l10n.projectOptions,
  entries: [
    AppMenuItem(
      label: l10n.expandAllProjects,
      onSelected: expandAllProjects,
    ),
    AppSubmenu(
      label: l10n.projectOptions,
      entries: [
        AppMenuItem(
          label: l10n.collapseAllProjects,
          onSelected: collapseAllProjects,
        ),
      ],
    ),
  ],
)
```

`AppMenuItem` 支持 `icon`、`enabled`、`selected` 和 `destructive`；
`AppSubmenu` 支持嵌套菜单与禁用状态。分组使用 `AppMenuDivider`。
业务页面不直接创建 Flutter 原生菜单，也不覆盖菜单颜色、圆角和行距。

长按内容预览菜单统一使用 `AppContextMenu`，底层使用
`cupertino_context_menu_plus` 提供内容预览与弹层定位，菜单和二级菜单仍沿用上述样式。
支持长按、鼠标右键、菜单键及 Shift+F10；长按时保留按压放大，弹层展开为 260ms、
收起为 180ms。长按菜单与 `AppDialog.show` 的居中弹窗使用统一的背景模糊和轻度暗色遮罩，
面板及内容保持清晰、不透明。系统开启减少动态效果时关闭可见动画。
居中弹窗沿用 260ms 展开、180ms 收起节奏，轻微缩放并淡入淡出，背景模糊与遮罩同步过渡。
选择操作时等待收起动画结束，再执行回调。

```dart
AppContextMenu(
  label: l10n.projectOptions,
  entries: [
    AppMenuItem(label: l10n.renameProjectItem, onSelected: renameProject),
  ],
  preview: projectPreview,
  child: projectRow,
)
```

`preview` 可传入不含交互的内容副本；省略时使用 `child` 的外观。项目与会话列表使用静态预览，
避免弹层复制列表行的交互状态。

## SVG 图标

本地 SVG 放在 `assets/icons/`，统一通过组件加载：

```dart
AppSvgIcon.asset('agent', size: 24)
AppSvgIcon.network(imageUrl, size: 24)
```

组件位于 `lib/shared/widgets/app_svg_icon.dart`。

独立图标按钮使用 `IconButton`，`AppTheme` 中的 `IconButtonTheme` 统一提供圆形中性灰
悬停和聚焦热区。悬停不会改变按钮尺寸，禁用状态不显示热区。
