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

本机安装 Flutter SDK 后，在项目目录执行：

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

认证相关代码位于 `lib/features/auth/data/`：

- `auth_api.dart`：定义图形验证码、短信验证码、验证码登录和当前用户接口
- `auth_repository.dart`：处理接口异常、Token 保存和登录态初始化
- `lib/core/storage/secure_storage.dart`：安全保存 access token

真实后端接入后，在 `lib/shared/providers/user_provider.dart` 调用
`signIn`，再根据项目的登录页增加路由守卫。

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
