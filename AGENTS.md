# Agent Guide

## 项目概览

这是一个 Flutter 应用模板，当前使用：

- Flutter Material 3
- Riverpod 状态管理
- go_router 路由
- Dio 网络请求
- SharedPreferences 本地偏好设置
- flutter_secure_storage 安全保存 Token
- Flutter 官方 ARB 国际化
- flutter_chat_ui 聊天界面
- flutter_markdown_plus Agent 消息渲染
- flutter_svg SVG 图标渲染
- toastification Toast 提示

## 目录约定

```text
lib/
├── app/                 # App 入口、路由、主题
├── core/                # 与业务无关的底层能力
│   ├── network/         # Dio、拦截器、网络异常
│   └── storage/         # 本地存储实现
├── features/            # 按业务拆分的模块
│   ├── chat/             # Agent 聊天页面和消息交互
│   └── auth/
│       ├── data/        # API、Repository、本地数据源
│       └── domain/      # 业务模型
├── l10n/                # ARB 文案与生成代码
└── shared/
    ├── providers/       # 统一状态管理和共享 Provider
    └── type/            # 共享类型定义
```

## 状态管理

所有全局状态 Provider 放在：

```text
lib/shared/providers/
```

当前 Provider 分类：

- `network_provider.dart`：Dio
- `storage_provider.dart`：SharedPreferences、Secure Storage
- `settings_provider.dart`：主题和语言
- `user_provider.dart`：用户登录状态

新增全局状态时，按职责创建独立文件，不要把所有 Provider 堆到一个文件中。

页面内部的分页、筛选和加载状态由页面本地管理。打开页面时请求的数据直接通过 Repository 获取，不为简单接口调用创建额外 Provider；跨页面或应用级共享的状态才使用 Provider。共享 Dio、存储等基础依赖继续通过现有 Provider 获取。

## 类型定义

共享枚举和类型放在：

```text
lib/shared/type/
```

文件按类型领域命名，例如 `user_type.dart`、`order_type.dart`，不要使用没有语义的通用文件名保存大量类型。

## 网络层

- 页面和 Provider 不直接拼接 Dio 请求。
- 后端请求 URL、HTTP 方法和请求参数按接口路径前缀统一管理，feature 文件不得直接发起 Dio 请求或定义接口路径。
- `/api_agent` 开头的接口统一在 `lib/core/network/network_agent_api.dart` 的 `NetworkAgentApi` 中定义，不放入 `NetworkApi`。
- 其他后端接口统一在 `lib/core/network/network_api.dart` 的 `NetworkApi` 中定义。
- feature 专属的 API 适配和业务数据转换放在对应 feature 的 `data/` 目录，通过对应的 `NetworkAgentApi` 或 `NetworkApi` 调用接口。
- 业务调用通过 Repository 暴露。
- 普通业务接口使用 `dioProvider`，`/api_agent` 接口使用 `agentDioProvider` 获取独立 Dio；Agent 服务地址和 Origin 通过 `AppConfig` 和环境文件管理。
- Token 由 `AuthInterceptor` 自动添加。
- 生产环境不要默认打开请求体和响应体日志。
- 正式接入后，将 `DioClient` 的 `baseUrl` 改为环境配置，不要硬编码生产地址。

## Agent 聊天

- 聊天页面位于 `lib/features/chat/presentation/chat_page.dart`。
- 聊天 UI 使用 `flutter_chat_ui` 和 `flutter_chat_core`。
- 文本消息通过 `MarkdownMessage` 渲染 Markdown。
- 当前页面的本地回复只是占位逻辑，真实接入时应新增 Chat Repository。
- SSE/WebSocket 流式响应通过 `InMemoryChatController.updateMessage` 更新消息内容。
- 不要把后端连接、流式解析和 Widget 绘制逻辑混在一起。

## 存储

- 普通偏好设置使用 `PreferencesStorage`。
- access token、refresh token 等敏感信息使用 `TokenStorage`。
- 业务代码通过 Provider 获取存储抽象，不直接创建插件实例。
- 测试中使用内存替身覆盖存储 Provider。

## 国际化

- 文案写入 `lib/l10n/app_zh.arb` 和 `lib/l10n/app_en.arb`。
- 不要直接修改 `lib/l10n/generated/` 下的生成文件。
- 修改 ARB 后执行：

```bash
flutter gen-l10n
```

- 页面通过 `AppLocalizations.of(context)!` 获取文案。
- 新增文案时，所有支持的语言文件都必须同步更新。

## 代码风格

- 优先使用现有依赖和项目结构，不重复引入功能相同的库。
- Widget 保持小而明确，复杂页面按功能拆分组件。
- 不在 UI 层保存 Token 或处理 JSON 解析。
- 不把网络请求、持久化和业务规则写进 Widget。
- SVG 图标统一通过 `AppSvgIcon` 加载，不要在页面中散落资源路径。
- 独立图标按钮使用 `IconButton`，通过 `AppTheme` 中的 `IconButtonTheme` 统一显示圆形中性灰 hover/聚焦热区；保持既定按钮尺寸，禁用时不显示热区，不在业务页面关闭 hover 反馈。
- Toast 统一通过 `AppToast` 调用，不要在业务页面直接使用第三方 Toast API。
- Bottom Sheet 统一通过 `AppSheet` 调用，不要在业务页面直接调用 Flutter Sheet API。
- 弹出菜单统一使用 `lib/shared/widgets/app_menu.dart` 的 `AppMenuButton`；长按内容预览菜单使用 `AppContextMenu`，第三方 `cupertino_context_menu_plus` 仅在共享组件内使用。菜单项使用 `AppMenuItem`，二级菜单使用 `AppSubmenu`，分隔线使用 `AppMenuDivider`。业务页面不直接使用 `PopupMenuButton`、`showMenu`、`MenuAnchor`、`MenuItemButton` 或 `SubmenuButton`，不要自行覆盖菜单样式。
- 菜单和二级菜单外层统一使用 20px 大圆角，内部菜单项使用两端半圆的胶囊矩形（StadiumBorder）；浅色主题为白底，深色主题跟随 surface，选中和悬停使用中性灰背景。
- 菜单参考苹果系统的排版：44px 最小行高、16px 文案、右侧操作图标、左侧选中勾选及细分隔线。菜单面板使用不透明背景，不添加悬停渐变或点击波纹动画。普通菜单和二级菜单即时展开；长按内容预览菜单保留按压放大、展开和收起动画，遵循系统减少动态效果设置。长按菜单与居中弹窗共用 `AppModalBackdrop` 的背景模糊和轻度暗色遮罩，内容本身保持清晰。
- 本地 SVG 放在 `assets/icons/`，资源目录在 `pubspec.yaml` 中统一声明。
- 新增公共类和复杂逻辑时添加简短注释，避免无意义注释。
- 保持空安全，不使用没有必要的 `dynamic`。

## 测试与验证

提交前必须执行：

```bash
flutter pub get
flutter analyze
flutter test
```

涉及平台代码时，再执行对应构建：

```bash
flutter build ios --release
flutter build macos --debug
```

新增状态管理时至少覆盖：

- 初始状态
- 状态更新
- 持久化恢复
- 清除状态
- 异常分支

## 修改原则

- 先阅读相关目录和 Provider，再开始修改。
- 保留用户已有改动，不使用破坏性 Git 命令。
- 不为了小功能进行无关重构。
- 修改完成后报告改动文件和验证结果。

## UI Conventions

## Environment Configuration

- Manage public environment settings in `config/env/*.json` and read them through `lib/core/config/app_config.dart`; do not add scattered `fromEnvironment` calls or hardcoded service URLs.
- Use `dart run tool/flutter_env.dart <environment> <Flutter command>` to keep Dart and iOS WeChat settings aligned. Local overrides use `*.local.json` and remain ignored by Git.

## Dialogs

- All centered dialogs follow the POPi Figma dialog style: https://www.figma.com/design/z1Yu18HoQT0qeUmc5zX9P9?node-id=1378-3319.
- Reuse `lib/shared/widgets/app_dialog.dart`. Use a surface background, 26px corners, centered confirmation copy, and horizontal pill action buttons. Confirmation dialogs default to 330px width and 30px padding; destructive confirmation uses #D63D43.
- Do not add a top-right close icon. Allow dismissal through cancel, the barrier, and platform back navigation where appropriate.
- Bottom sheets used for content selection remain separate from centered dialogs.
- Centered dialogs opened through `AppDialog.show` use a full-screen blurred backdrop with the shared `AppModalBackdrop` settings; keep the dialog surface opaque.
- Dialog transitions use the shared menu timing (260ms enter, 180ms exit), a subtle scale and fade, and animated backdrop intensity. Disable transitions when the system requests reduced motion.
