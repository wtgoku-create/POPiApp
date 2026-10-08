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

## 网络请求

通过 `ref.read(dioProvider)` 获取 Dio 实例。开发环境 API 地址为
`https://wwwtest.popi.art`，生产环境为 `https://www.popi.art`。

## 环境配置

统一配置文件位于 `config/env/development.json` 和 `config/env/production.json`，
Dart 代码只通过 `lib/core/config/app_config.dart` 读取配置。

| 配置项 | 用途 |
| --- | --- |
| `APP_ENV` | 环境名称 |
| `API_BASE_URL` | 后端根地址，接口路径自身包含 `/api_client` |
| `API_ENABLE_LOGGING` | Debug 模式网络日志开关 |
| `WECHAT_APP_ID` | 微信开放平台 App ID |
| `WECHAT_UNIVERSAL_LINK` | 微信回调 Universal Link，需使用 HTTPS 域名 |
| `DOUYIN_CLIENT_KEY` | 抖音开放平台移动应用 Client Key |
| `DOUYIN_UNIVERSAL_LINK` | 抖音 iOS Universal Link，可与微信共用 |
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

脚本将 JSON 传给 Flutter 原生 `--dart-define-from-file`，并自动生成
`ios/Flutter/Environment.xcconfig`，同步微信 URL Scheme 和 Associated Domains。
新域名仍需在微信开放平台和域名服务器配置对应的 Universal Link/AASA。
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

Android 使用官方 `opensdk-china-external` 和 `opensdk-common` 0.2.0.10，
通过同一 MethodChannel 接收环境配置中的 Client Key，仅在用户发起授权时初始化。
`DouyinEntryActivity` 接收 SDK 回调，校验 state 后将授权码交给现有登录接口；
取消、超时和引擎销毁会清理待处理请求。Android 需要安装支持授权的抖音客户端，
开放平台登记的包名 `com.popiai.app`、APK 签名和 Client Key 必须匹配。
Debug 默认使用本机调试签名，真机登录前需要在平台配置相应签名，或使用已登记的签名打包。

认证相关代码位于 `lib/features/auth/data/`：

- `auth_api.dart`：定义图形验证码、短信验证码、验证码登录和当前用户接口
- `auth_repository.dart`：处理接口异常、Token 保存和登录态初始化
- `lib/core/storage/secure_storage.dart`：安全保存 access token

真实后端接入后，在 `lib/shared/providers/user_provider.dart` 调用
`signIn`，再根据项目的登录页增加路由守卫。

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
