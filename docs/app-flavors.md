# 双应用构建与后端对接

## 应用配置

| flavor | Bundle ID / applicationId | 安装名称 | 商品前缀 |
|---|---|---|---|
| popi | com.popiai.app | POPi AI | popi. |
| popistudio | com.popistudio.app | POPi Studio | popistudio. |

两个 flavor 共用业务代码、API 地址和后端账号权益。本地登录状态与本地数据按应用隔离。
不得把服务域名、namespace、微信 App ID 中的 popi 全局替换。

## 构建

```sh
flutter run --flavor popi
flutter run --flavor popistudio
flutter build apk --release --flavor popi
flutter build apk --release --flavor popistudio
flutter build ios --simulator --debug --flavor popi
flutter build ios --simulator --debug --flavor popistudio
flutter build ipa --release --flavor popi
flutter build ipa --release --flavor popistudio
```

Android APK 位于 build/app/outputs/flutter-apk/app-<flavor>-release.apk。
Android 使用现有 android/key.properties；未提供时仍可能回退 debug 签名，正式发布必须提供正式签名。
iOS 打开 ios/Runner.xcworkspace，选择 popi 或 popistudio Scheme。
旧通用 Runner Scheme 已移除，必须明确选择应用。
两套应用分别需要匹配 Bundle ID 的描述文件，可以复用团队发布证书。
新 Scheme 不启用原 test.storekit，真实商品查询请使用真机沙盒或 TestFlight。
模拟器构建不会证明商店商品、签名和支付可用。

GitHub Actions 手动构建选择 flavor；v* 标签默认 POPi。
Android 继续使用 ANDROID_KEYSTORE_BASE64、ANDROID_KEYSTORE_PASSWORD、ANDROID_KEY_ALIAS、ANDROID_KEY_PASSWORD。
iOS 共用 IOS_CERTIFICATE_BASE64、IOS_CERTIFICATE_PASSWORD、IOS_TEAM_ID。
POPi 使用 IOS_PROVISIONING_PROFILE_BASE64，Studio 使用 IOS_STUDIO_PROVISIONING_PROFILE_BASE64。
Bundle ID 来自 flavor，不再读取 IOS_BUNDLE_ID secret。描述文件名称从文件解析。
TestFlight 仅在手动明确选择上传时执行，使用已有 APPSTORE_ISSUER_ID、APPSTORE_KEY_ID、APPSTORE_PRIVATE_KEY。
产物名称包含 flavor。本次不会触发远程发布或配置 secrets。

## 后端接口要求

请求头 X-App-Identifier 为当前应用标识。后端商品列表必须按此返回当前应用的 apple_product_id：
- /api_client/users/pointPackage/list
- /api_client/products/plan/list

客户端仅接受下面的商品 ID；不能返回另一款应用的 ID，也不能继续返回 popi.membership.starter.30d。
同一行的两套 Apple ID 映射至同一业务套餐 ID，业务套餐 ID 由后端现有数据确定，不按客户端价格猜测。

| 后缀（分别加 popi. 和 popistudio.） | 类型 | 对应内容 |
|---|---|---|
| credits.600 | consumable | 600积分 |
| credits.1000 | consumable | 1000积分 |
| credits.2000 | consumable | 2000积分 |
| credits.6000 | consumable | 6000积分 |
| credits.10000 | consumable | 10000积分 |
| credits.20000 | consumable | 20000积分 |
| max.36500.monthly | nonRenewingSubscription | Max 30天会员 |
| pro.28000.monthly | nonRenewingSubscription | Pro 30天会员 |
| plus.14400.monthly | nonRenewingSubscription | Plus 高频30天会员 |
| plus.5500.monthly | nonRenewingSubscription | Plus 30天会员 |
| starter.1750.monthly | nonRenewingSubscription | Starter 30天会员 |

会员 ID 的 monthly 后缀不表示自动续费，实际类型为非续期订阅。
积分发放数量、赠送积分和有效期由业务套餐决定，不能仅解析商品 ID 决定权益。

POST /api_client/payments/apple/verify 保留现有字段并增加 bundle_id：

```json
{
  "bundle_id": "com.popistudio.app",
  "product_id": "popistudio.credits.600",
  "business_product_id": "现有业务套餐ID，补发时可能为空",
  "business_product_type": "consumable",
  "purchase_id": "Apple交易ID",
  "verification_data": "Apple验证凭证",
  "transaction_date": "交易时间"
}
```

返回沿用 status=0000 的成功协议。只有持久化发放成功或同一用户的同一交易已发放，才能返回成功。
后端必须验证 Apple 凭证的签名、真实 Bundle ID、商品 ID、交易 ID、环境及撤销状态。
请求头、bundle_id、套餐 ID、类型和时间都是客户端提示，不能代替 Apple 验证结果。
支持两套应用的沙盒配置；生产与沙盒交易及权益应按现有环境隔离，不能让沙盒获得生产付费权益。
使用环境、应用标识、已验证交易 ID 建立唯一约束，交易记录和权益发放原子提交。
同一交易重试不得重复发积分或延长会员；跨账号重放不得重新归属。
补发交易可能没有 business_product_id，后端必须根据已验证的应用和商品查映射。
已有交易的账户归属必须持久化，不能在重试时改成当前任意登录用户。

两个 App 登录同一业务账号后读取相同余额和会员。沿用现有会员延期、跨等级购买、积分有效期及发放规则；
请后端同事确认这些规则，并提供同等级重复购买、跨等级购买、到期购买的预期结果。
客户端不计算到期时间，不通过恢复消耗型购买推算余额。

## 微信与验收依赖

Studio 微信应用已通过审核，客户端已开启入口。Studio App ID 为 wx0d9c23195606fc80，POPi 保留 wxf99ad5d5c7b4fe37。
两款当前使用 https://app.popi.art/WeChat/，Dart 注册参数按 flavor 选择，Studio 三套 iOS 配置的 URL Scheme 与 App ID 一致。
不再使用通用 WECHAT_APP_ID / WECHAT_UNIVERSAL_LINK Dart define 覆盖，避免与原生 flavor 配置不一致。
网站 AASA 必须保留原应用，并添加 Studio 的应用标识及 /WeChat/* 路径。应用标识使用证书实际 App ID Prefix 加 Bundle ID；若 Prefix 为当前团队 ID，则 Studio 为 84GT698GKX.com.popistudio.app。
同一域名与路径关联多个 App 的回调路由需要真机验证，尤其两款同时安装时；若发生串应用，应为 Studio 改用独立回调路径，并同步微信后台、客户端与 AASA。
Apple App ID 需要开启 Associated Domains，发布描述文件需包含该能力；微信后台需登记 com.popistudio.app 及实际 Android 发布签名。
后端按 X-App-Identifier=com.popistudio.app 选择 Studio App ID 和 AppSecret；AppSecret 仅保存在后端。网站和后端配置未在本次修改中部署。
后端按应用选择微信凭据，通过经验证的 UnionID 或手机号关联业务账号，不把不同应用的 OpenID 直接等同。

上线前由客户端与后端共同完成：
- 两款 App 的11个商品均可查询；积分与会员金额、名称和类型正确。
- 沙盒购买成功、取消、验证失败后补发、重复交易不重复发放。
- 会员30天规则、同等级与跨等级购买符合已确认后端规则。
- 两款 App 同时安装且同账号权益一致；其他账号不能重放交易获得权益。
- 微信审核通过后验证两款同时安装时的回调不会串应用。

本地自动化测试及模拟器构建不能替代上述沙盒、后端和商店验证。

## 本次本地验证（2026-09-15）

- flutter analyze 通过；完整 flutter test 83项通过。
- Studio flavor 的商品目录、验证请求与商品列表请求头专项测试7项通过。
- 两套 Android debug APK 构建成功，使用 aapt 核对包名与显示名称；当前无 Android 设备，未实际安装。
- 两套 iOS debug 模拟器构建成功，在同一 iPhone 17 模拟器安装、启动并核对独立容器和显示结果。
- 正式证书签名、GitHub 远程工作流、真实 Apple 沙盒购买、后端权益发放和 Studio 微信未完成端到端验证。
