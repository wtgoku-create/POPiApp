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
- Markdown 消息渲染
- flutter_chat_ui Agent 聊天界面
- SVG 图标组件与本地资源目录
- Bottom Sheet 示例
- Toast 提示封装

## 使用

本机安装 Flutter SDK 后，在项目目录执行：

```bash
flutter create .
flutter pub get
flutter run
```

`flutter create .` 会补齐 Android、iOS、Web 等平台目录，不会覆盖 `lib/` 和 `pubspec.yaml`。

## 目录

```text
lib/
├── app/                 # App 入口、路由、主题
├── core/                # 网络层、存储层、基础能力
├── features/            # 按业务拆分的功能模块
│   ├── chat/             # Agent 聊天页面
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

通过 `ref.read(dioProvider)` 获取 Dio 实例。生产项目中请在
`lib/core/network/dio_client.dart` 中配置正式的 `baseUrl`、认证拦截器和错误处理。

认证相关代码位于 `lib/features/auth/data/`：

- `auth_api.dart`：定义登录和当前用户接口
- `auth_repository.dart`：处理接口异常和 Token 保存
- `lib/core/storage/secure_storage.dart`：安全保存 access token

真实后端接入后，在 `lib/shared/providers/user_provider.dart` 调用
`signIn`，再根据项目的登录页增加路由守卫。

## Markdown 消息

使用 `lib/shared/widgets/markdown_message.dart` 渲染 Agent 返回的 Markdown：

```dart
MarkdownMessage(data: message.content)
```

后端通过 SSE 或 WebSocket 增量返回内容时，只需要更新消息状态并重新构建
`MarkdownMessage`，不需要修改渲染组件。

## Bottom Sheet

Sheet 示例页面位于 `lib/features/sheet/presentation/sheet_demo_page.dart`，支持：

- 普通 `showModalBottomSheet`
- 可拖拽的 `DraggableScrollableSheet`

访问路由 `/sheet-demo`，首页也提供了入口。

Sheet 统一通过 `lib/shared/widgets/app_sheet.dart` 调用：

```dart
AppSheet.show(context: context, builder: (_) => const YourContent());
AppSheet.showDraggable(
  context: context,
  builder: (_, controller) => ListView(controller: controller),
);
```

## Toast

项目使用 `toastification`，业务页面通过 `AppToast` 调用：

```dart
AppToast.success(context, '操作成功');
AppToast.error(context, '操作失败');
AppToast.info(context, '提示信息');
```

封装位置：`lib/shared/widgets/app_toast.dart`。

## SVG 图标

本地 SVG 放在 `assets/icons/`，统一通过组件加载：

```dart
AppSvgIcon.asset('agent', size: 24)
AppSvgIcon.network(imageUrl, size: 24)
```

组件位于 `lib/shared/widgets/app_svg_icon.dart`。

当前聊天页中的 Agent 回复是本地占位逻辑，位于
`lib/features/chat/presentation/chat_page.dart` 的 `_handleMessageSend`。
接入真实后端时，将这段逻辑替换为 Chat Repository，并使用
`InMemoryChatController.updateMessage` 更新流式消息内容。
