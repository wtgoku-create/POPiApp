# DSH FFmpeg 通用剪辑 · 2026-10-26

已发布至 https://124.222.185.31/ 。后端和 Web 版本为 `20261026T082539Z`，Skill ID 为 `ffmpeg-video-edit`。发布编号是构建开始时间，不代表线上版本按名称排序。

## 使用

刷新测试网页，在当前 Bot 的能力页启用「FFmpeg 通用剪辑」，将视频和可选配乐从本地上传或从素材库选中后随消息发送。支持裁切、同源多段或多视频拼接、contain/cover 画幅转换、定时中文字幕、静音、原声和配乐音量混合。成片异步回到原会话和素材库，不要求 DSH 进程一直存活。

上限为 8 个片段、120 秒成片、50 条字幕、720p/1080p、128 MiB 输出、512 MiB 唯一输入、16 个活动任务，后台单并发。只接受已有受保护素材 ID 和结构化计划，输出 H.264/AAC MP4，无新依赖，不调用外部付费媒体生成。

## 实现文件

- PAPP `services/agent/local/skills/ffmpeg-video-edit/`：原生 Skill 与内联读取的计划合同、固定资源摘要。
- PAPP `video-edit-engine.mjs`：固定 FFmpeg 参数、输入校验、编码/字幕/音轨和进程回收。
- PAPP `video-edit-worker.mjs`：冻结授权、流式源 SHA 校验、持久任务、幂等、取消/恢复、稳定资产和消息、终态清理。
- PAPP `dsh-video-edit-plugin.mjs`、`video-edit.patch.yml`、`harness-runtime.mjs`：DSH 原生发现和 inputs/submit/status/cancel 工具。
- PAPP `server.mjs`、`session-config.mjs`、`store.mjs`、`message-attachments.mjs`、`activity-projection.mjs`、`installed-skills.mjs`：私有桥、能力开关、任务投影和仅元数据附件。
- App `lib/features/demo/data/demo_repository.dart`：将剪辑任务纳入已有媒体任务观察与恢复。能力页沿用通用 Skill ID 校验，无新增编辑器页面。
- 新增后端引擎/worker/plugin/HTTP/SDK 测试及 App `test/demo_video_edit_delivery_test.dart`。

## 验证

- 本机 Node 全量：407 通过，0 失败，1 项平台相关跳过；Linux 非 root 全量：408 通过，0 失败，0 跳过。
- 锁定官方 DSH SDK 实际读取 Skill 合同，调用提交工具，经真实 worker 和 FFmpeg 生成 MP4，并将同一资产与单条消息落入快照；模型仅为 loopback fixture，未调用付费媒体。
- Linux 原生 Session M0 恢复验证通过。复用原已验证的 Linux Node/DSH 安装和 Linux 运行锁，未将 macOS 运行锁作为部署资格。
- Linux 服务用户实际生成 1080×1920、0.833333 秒 H.264/AAC 成片，包含不同尺寸片段、静音片段、裁切拼接、中文字幕和配乐混合；输出 27,633 字节。
- Flutter pub get、analyze 通过；全量 2,173 通过、2 项既有跳过，最终剪辑交付及能力设置回归 36 项通过；Web release 构建通过。
- 在线登录通过；FFmpeg Skill `installed/bound/available` 均为 true，四个工具已绑定，默认不替用户开启。
- 未登录 API 401，私有桥公网 404，跨源写入 403；已有私有视频 HEAD 200、Range 206。
- 公网 `main.dart.js` SHA-256：`b1a4b3545f681fedb1b83c3049fc1fd2ad3103db26c56083ee56ed932d7987c2`，包含后台剪辑观察逻辑。

## 发布与保留

切换前发现测试服已另行发布 `20261026T082836Z`，旧基线切换被拒绝，没有中断线上。随后比对其源码清单：233 项完全相同、无缺失文件，其余差异为 FFmpeg 本次实现、验证记录和运行锁。确认参考案例 Skill 的原资源及能力保留后，才以该线上版本作为回退点切换。

保留 10 个会话、35 项资产及全部既有 Bot 配置；风格短片 6 项 ready，参考案例 Skill 仍可用。凭据和 Caddy 配置保持原位。备份与上一版指针位于 `/var/backups/popi-ffmpeg-20261026T082539Z/`；本次状态仍为 v2，仅增加剪辑任务字段。

本机完整记录位于 `.omx/state/ffmpeg-video-edit/`。原生 App 未重新打包；新网页已包含动态能力和后台剪辑跟进。很长源视频的后段目前仍按顺序解码，可能达到 180 秒执行超时；6 小时仅为源时间轴校验范围，不是性能承诺。
