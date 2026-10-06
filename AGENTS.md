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

页面或业务专属的临时状态可以放在对应 `features/<feature>/presentation/` 下。

## 类型定义

共享枚举和类型放在：

```text
lib/shared/type/
```

文件按类型领域命名，例如 `user_type.dart`、`order_type.dart`，不要使用没有语义的通用文件名保存大量类型。

## 网络层

- 页面和 Provider 不直接拼接 Dio 请求。
- API 定义放在对应 feature 的 `data/` 目录。
- 业务调用通过 Repository 暴露。
- 统一使用 `dioProvider` 获取 Dio。
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
- Toast 统一通过 `AppToast` 调用，不要在业务页面直接使用第三方 Toast API。
- Bottom Sheet 统一通过 `AppSheet` 调用，不要在业务页面直接调用 Flutter Sheet API。
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
