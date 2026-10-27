# 风格短片发布记录 · 2026-10-25

Web 与 DSH 已发布至 https://124.222.185.31/ 。iOS `1.0.0 (6001)` 已上传 TestFlight，Apple 返回 `VALID / IN_BETA_TESTING`，现有内部测试用户可更新；Android 按用户要求暂缓。

## 当前版本

- Web：`20261025T145907Z`
- DSH：`20261025T144055Z`
- App 源码：`7987d4fc99e6830b1fd3ce950784c81c2bc49d19`
- iOS 流程：[40204816378](https://github.com/wtgoku-create/POPiApp/actions/runs/40204816378)，已成功交付 `1.0.0 (6001)`。
- 已保留上一版公开 Web `20261025T111939Z` 的创作记忆、角色参考与移动端导航。早期 5901 签名产物未上传，不能作为本次可安装版本。

## 功能

Bot 在「能力」启用「制作风格短片」后，对话输入区与＋菜单同步出现选择风格入口。选择风格只保存草稿；发送主题后生成分镜，用户可填写调整意见或确认制作，完成视频沿现有私有素材链路进入聊天与素材库。关闭能力后两个新建入口隐藏，已受理的任务仍保留。

目录同步固定上游 commit `413a6bd6d78ebd3bdd5abaec9538a26867f890df` 的 59 项名称、说明与真实封面；六个受控 2D 适配器可制作：`impasto`、`ink-wash`、`swiss-motion`、`paper-lantern`、`pixel-rpg`、`blueprint`。首版接受文字主题，15/30 秒，9:16、16:9 或 1:1。其他53项保持可浏览、不可制作。修订分镜是整份计划重生成；首版不开放旁白或未经模式检查的配乐。用户明确取消追加模型样片与艺术评分作为发布门槛，资源完整性、正常沙盒、配置、授权、数据校验和成片入库检查继续保留。

## 验证与保留

- 同一 lib/test 源码 2,075 项测试通过；分析、格式检查和 Web release 构建通过。
- Linux 后端 349/349 测试通过、无跳过；锁定 DSH SDK M0 通过。
- 与正式服务一致的 nonroot/NoNewPrivileges/PrivateTmp/ProtectSystem/ProtectHome 环境机械检查通过，目录返回 59 项、6 项 ready。
- 真实 App 的既有分镜经调整、确认后完成并展示同一私有成片资产；未追加模型样片任务。
- 发布后登录、开关、风格目录、选择保存、刷新恢复及 390×844 移动布局通过；＋菜单与创作偏好界面可用。
- 原有6个会话、10项资产保留；另通过界面创建「风格导演」方便直接试用，未发送新的制作请求。
- 未登录目录401、内部路径404、跨源写入403；服务无重启。凭据保持原服务器配置。
- 发布备份 `/var/backups/popi-harness-20261025T144055Z/`。v2状态若要回到v1服务须同时恢复匹配的状态；不可仅回退二进制而丢弃后续用户写入。
- 主工作区 HEAD、主 Git index 和用户既有改动保持；使用独立发布索引及分支。资格检查改为短临时目录，避免 Chrome Unix socket 路径过长，不降低浏览器沙盒。

## 文件范围

客户端主要为 `demo_style_film_models.dart`、三个风格 UI 组件、`demo_repository.dart`、`demo_chat_controller.dart`、会话配置、composer、能力设置、NetworkAgentApi 和中英文 ARB。服务端为 `style-film-*`、专用 `film_plan_submit` 插件、store、server、私有素材导入及部署脚本。通过既有网络、素材与弹层组件复用实现，没有新增应用依赖。

以下为相对上一版原生发布基线的 App/部署文件清单（含继承已上线 Web 功能）：

```text
M	deploy/harness/README.md
M	deploy/harness/activate-server.sh
M	deploy/harness/install-release.sh
M	deploy/harness/package-source.py
M	deploy/harness/popi-harness.service
A	deploy/harness/prepare-film-runtime.sh
M	deploy/harness/prepare-server.sh
M	deploy/harness/server.mjs
M	deploy/harness/site-caddy.test.mjs
M	deploy/harness/site.caddy.template
A	docs/design/dsh-style-film-interaction.md
M	lib/core/network/network_agent_api.dart
M	lib/features/demo/data/demo_repository.dart
M	lib/features/demo/data/demo_website_character_catalog.dart
M	lib/features/demo/domain/demo_assistant_profile.dart
M	lib/features/demo/domain/demo_capability_catalog.dart
M	lib/features/demo/domain/demo_models.dart
A	lib/features/demo/domain/demo_style_film_models.dart
M	lib/features/demo/presentation/demo_chat_controller.dart
M	lib/features/demo/presentation/demo_chat_page.dart
M	lib/features/demo/presentation/demo_home_page.dart
M	lib/features/demo/presentation/demo_settings_page.dart
A	lib/features/demo/presentation/demo_style_film_job_card.dart
A	lib/features/demo/presentation/demo_style_film_review_sheet.dart
A	lib/features/demo/presentation/demo_style_film_sheet.dart
M	lib/features/demo/presentation/widgets/demo_content_role_avatar.dart
M	lib/features/session/presentation/widgets/popi_message_composer.dart
M	lib/l10n/app_en.arb
M	lib/l10n/app_zh.arb
M	lib/l10n/generated/app_localizations.dart
M	lib/l10n/generated/app_localizations_en.dart
M	lib/l10n/generated/app_localizations_zh.dart
M	lib/shared/providers/harness_access_provider.dart
A	test/composer_context_actions_test.dart
M	test/demo_activity_repository_test.dart
M	test/demo_assets_design_test.dart
M	test/demo_assistant_profile_repository_test.dart
M	test/demo_chat_activity_test.dart
M	test/demo_chat_attachment_test.dart
M	test/demo_chat_header_test.dart
M	test/demo_context_contract_test.dart
M	test/demo_conversation_list_test.dart
A	test/demo_creative_memory_test.dart
A	test/demo_creative_memory_visual_test.dart
M	test/demo_file_import_sheet_test.dart
M	test/demo_flow_test.dart
M	test/demo_harness_question_repository_test.dart
M	test/demo_harness_repository_test.dart
M	test/demo_harness_voice_input_test.dart
M	test/demo_owned_assets_test.dart
M	test/demo_server_configuration_test.dart
M	test/demo_server_ui_test.dart
M	test/demo_settings_reference_test.dart
A	test/demo_style_film_repository_test.dart
A	test/demo_style_film_ui_test.dart
A	test/demo_website_character_avatar_test.dart
M	test/demo_website_character_catalog_test.dart
M	test/native_harness_media_test.dart
A	test/style_film_api_test.dart
```

完整私有发布证据位于 `.omx/state/style-film-integration/`，不包含在公开安装包中。Apple 于 `2026-10-25T15:15:31Z` 确认6001已处理且可内部测试。现有账号无外部测试组或公开邀请链接；新 iOS 二进制尚未另行进行真实设备验收。IPA SHA-256：`8bea737a3436e0b06966300d174eff10a2cbcd48e39ae10c1d52465fa7162a63`。
