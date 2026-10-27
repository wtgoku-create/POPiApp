# 图片粘贴与文档读取发布记录 · 2026-10-26

Web / DSH：<https://124.222.185.31/>，发布版本 `20261026T042201Z`。

- Mac：`1.0.0 (6101)`，Apple Silicon / Intel 通用包，Developer ID 签名、Apple 公证 Accepted、stapler 和 Gatekeeper 验证均通过。
- [Mac DMG 下载](https://124.222.185.31/downloads/POPi-macos-1.0.0-6101-bc7d89f98e9d.dmg)，SHA-256 `bc7d89f98e9d534fcdfd91073f8ef2010b113dc5e687abdbbb18fafb41ea83e2`。
- iOS：`1.0.0 (6101)`，Apple 返回 `VALID / IN_BETA_TESTING`，现有内部测试用户可通过 TestFlight 更新。当前没有公开邀请链接或外部测试组。
- [iOS 构建记录](https://github.com/wtgoku-create/POPiApp/actions/runs/40269001588)；[Mac 公证记录](https://github.com/wtgoku-create/POPiApp/actions/runs/40269418254)。
- App 源码快照：`15fc321995b2b7a313c0b76905db266aad64765a`。Android 共享实现已同步；按用户此前要求继续暂缓 APK 构建与发布。

## 使用与限制

Web 聚焦输入框后可粘贴图片；Mac 支持 Cmd+V，原生长按菜单及＋菜单提供「粘贴图片」。普通文字粘贴保留。图片先验证并上传为草稿附件，用户仍需主动发送。

通过设备上传或素材库选择 PDF、DOC、DOCX、PPT、PPTX、TXT、MD。文档解析完成后成为可发送附件；预览显示提取文字、页或幻灯片出处及 OCR/截断信息，原文件仍可按真实格式下载。解析失败保留输入和既有附件，以 Toast 提示。

| 约束 | 上限 |
|---|---|
| 图片单个及单条消息图片合计 | 20 MiB |
| PDF / Word / PPT 单个 | 20 MiB |
| TXT / Markdown 单个 | 2 MiB |
| 单条消息全部附件 | 最多10个、合计50 MiB |
| PDF / PPT | 最多100页 / 100张幻灯片 |
| 文档保存的提取文字 | 最多500,000 Unicode字符，超出明确截断 |
| 当前与历史附件共同进入模型的文字 | 最多65,536 Unicode字符，超出明确截断/省略 |

DOCX 的软分页取决于排版引擎，本版使用逻辑章节并标明估算页数。解析预览不是 Office 原版式编辑器。扫描 PDF 使用简体、繁体中文与英语 OCR；识别受原扫描质量影响。加密文件需先移除密码；复杂度、OCR总像素或180秒处理预算超限会明确失败。风格短片首版仍仅接受文字主题，普通对话文档接入不代表风格短片已支持附件参考。

## 实现与验证

复用现有上传、素材、script类型及网络/弹层组件，新增文档metadata和私有提取文本，避免迁移全部素材枚举；没有新增 Flutter/npm 依赖。原二进制字节、MIME和SHA保持；提取文本sidecar绑定原件/解析版本/文字摘要，并检查owner、权限、普通文件与摘要。文件内容仅是引用资料，不能授予命令权限。

PDF 使用 Poppler，扫描件用 Tesseract；DOCX/PPTX仅在受限ZIP/XML读取中提取；旧DOC/PPT由独立非root服务转换。转换服务禁用网络、仅AF_UNIX、NoNewPrivileges，不能访问DSH凭据或会话状态，接受有界字节协议而非任意路径或命令；宏关闭、时间/资源受限。API解析独立单并发，忙时可用原操作重试，不排无限队列。

- App全量及CI：2,139项测试通过，分析、格式、Web release和Mac universal release构建通过。早期并行构建期间旧pre-commit测试触发30秒超时；控制并发后的完整重跑及独立CI均通过，未修改该测试。
- Clipboard：7个native channel和4个真实Chrome ClipboardEvent测试通过；涵盖正常文字不拦截、失焦不读取、事件去重、迟到回调与大小限制。
- Linux：362/362后台测试通过、无跳过；DSH SDK M0通过。最终文档上下文OCR说明修订后，相关12项测试再次通过。
- PDF、DOCX、PPTX、DOC、PPT、扫描PDF的实际解析、来源、原字节/SHA/MIME、HEAD/Range、幂等均通过；服务重启后六份提取文字仍可读。
- 一次真实DSH对话读取了六种测试附件，返回其中的预期编号；另验证真实中英文扫描件OCR。
- 发布后Web实际图片paste→上传→草稿、PDF选择→解析→详情、中文/英文提取文字和390×844移动端预览均通过。
- 发布前备份，原有7会话、21素材和配置逐字节保留。随后烟测新建「文档助理」及明确命名的测试素材；没有生成额外媒体样片。
- 主工作区HEAD、主index与用户既有改动保留；快照完整保留已上线创作记忆、角色参考、风格短片和既有界面更新。Mac/iOS构建已通过，新的iOS二进制尚未另行做真实设备手动验收。

## 改动文件

后端：`document-parser.mjs`、`document-parser-helper.py`、`document-converter-daemon.py`及fixtures/tests；上传、私有文本读取、消息预算和DSH提示块；部署运行依赖、转换服务、启动顺序与Python源码打包。

App与部署快照相对上一版原生发布的文件范围如下，包含本任务前已上线共享界面更新：

```text
android/app/src/main/kotlin/com/popistudio/app/ClipboardImageBridge.kt
android/app/src/main/kotlin/com/popistudio/app/MainActivity.kt
deploy/harness/activate-server.sh
deploy/harness/install-release.sh
deploy/harness/package-source.py
deploy/harness/popi-document-converter.service
deploy/harness/popi-harness.service
deploy/harness/prepare-document-runtime.sh
deploy/harness/prepare-server.sh
ios/Runner.xcodeproj/project.pbxproj
ios/Runner/AppDelegate.swift
ios/Runner/ClipboardImageBridge.swift
lib/core/clipboard/clipboard_image_validation.dart
lib/core/clipboard/clipboard_images.dart
lib/core/clipboard/clipboard_images_contract.dart
lib/core/clipboard/clipboard_images_native.dart
lib/core/clipboard/clipboard_images_web.dart
lib/core/network/network_agent_api.dart
lib/features/demo/data/demo_file_picker.dart
lib/features/demo/data/demo_media_exporter.dart
lib/features/demo/data/demo_repository.dart
lib/features/demo/domain/demo_models.dart
lib/features/demo/domain/demo_upload_file.dart
lib/features/demo/presentation/demo_assets_page.dart
lib/features/demo/presentation/demo_chat_page.dart
lib/features/demo/presentation/demo_desktop_workspace.dart
lib/features/demo/presentation/demo_file_import_sheet.dart
lib/features/demo/presentation/demo_home_page.dart
lib/features/demo/presentation/demo_script_detail_page.dart
lib/features/demo/presentation/widgets/demo_conversation_list_item.dart
lib/features/demo/presentation/widgets/demo_desktop_sidebar.dart
lib/features/demo/presentation/widgets/demo_document_cover.dart
lib/features/demo/presentation/widgets/demo_image_stack.dart
lib/features/session/presentation/widgets/popi_message_composer.dart
lib/l10n/app_en.arb
lib/l10n/app_zh.arb
lib/l10n/generated/app_localizations.dart
lib/l10n/generated/app_localizations_en.dart
lib/l10n/generated/app_localizations_zh.dart
macos/Runner.xcodeproj/project.pbxproj
macos/Runner/ClipboardImageBridge.swift
macos/Runner/MainFlutterWindow.swift
test/clipboard_images_test.dart
test/clipboard_images_web_test.dart
test/composer_context_actions_test.dart
test/composer_keyboard_submission_test.dart
test/demo_assets_design_test.dart
test/demo_chat_latest_scroll_test.dart
test/demo_chat_visual_polish_test.dart
test/demo_desktop_workspace_test.dart
test/demo_document_upload_test.dart
test/demo_file_import_sheet_test.dart
test/demo_image_stack_test.dart
test/demo_owned_assets_test.dart
test/demo_style_film_ui_test.dart
test/demo_uploaded_script_test.dart
```

发布备份：`/var/backups/popi-harness-20261026T042201Z/`。回滚时应先确认新增文档资产/sidecar与旧服务的兼容性，不能为回退安装包而丢弃发布后的用户状态。转换服务需跟随目标release更新并先于Harness启动。

私有证据：`.omx/state/document-input-integration/`；不写入公开安装包。
