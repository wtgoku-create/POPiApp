# 官方 Office 转换内核复用 · 2026-10-26

发布版本：`20261026T060241Z`，入口 <https://124.222.185.31/>。

本次仅更新服务端 DOC/PPT 转换叶子，复用 DSH 官方采用的锁定 `@deepseek-ai/libreoffice-kit@0.1.5` Linux WASM。没有启用整套 DSH Office UI／Cordis Remote，也没有改动现有 App、HTTP API、登录鉴权、素材 ID、原文件、限额或 OCR。Web 发布版本保持 `20261026T042201Z`；已发布 Mac/iOS 6101 无需重新打包。

## 最小改动与简化

- 保留原 Python UDS 隔离封装和有界字节协议，转换内部改为固定 Node helper 调用官方 `createConverter → render → dispose`。
- 移除自建的系统 LibreOffice profile、启动参数及 bwrap/sandbox-exec 降级路径，系统 LibreOffice 不再是生产转换依赖。既有系统软件没有被卸载；旧工具只用于生成回归测试文件。
- 没有增加 npm/Flutter 依赖或修改 runtime package-lock。Linux npm ci 与运行时 seal 仍验证同一依赖闭包，含官方 WASM 引擎和许可资源。
- 保留 PDF/OOXML 文字提取、OCR、sidecar、HEAD/Range、幂等和已存文档读取；已有原件、assetId 及解析 sidecar 不重建。

## 验证

- 先完成独立官方引擎验证：7/7，涵盖真实 DOC/PPT、损坏、输入/输出超限、超时和主动取消，失败后无 PDF 残留。
- 同生产权限与资源约束的精确环境复验：DOC/PPT 2/2，分别1页和2张幻灯片，读取预期标记；OOM/oom_kill均为0。
- 候选 release 及其实际 SDK 路径再次启动后，DOC 8.7秒、PPT 10.1秒，页数、来源和文字正确。
- Linux完整后端369/369、无跳过；锁定DSH SDK M0通过。新增适配器／daemon错误映射／超时清理测试与现有文档上传测试通过。
- 六类输入（PDF、DOCX、PPTX、DOC、PPT、扫描PDF）实际上传、文字、原件SHA/MIME、HEAD/Range、幂等均通过，扫描件继续使用OCR。QA API重启后六份文本仍可读。
- 公网登录后DOC/PPT上传、页数、提取文字、原字节、HEAD/Range、幂等通过；未登录401、内部路径404、跨源写入403。
- 发布前确认任务及上传空闲，备份状态和服务单元；先转换服务再Harness切换。原有8个会话、23项素材与凭据保留。重启只补齐一个已有会话的空 `questionResponses` bookkeeping 字段，无旧数据被修改。随后公网烟测新增两个明确命名的测试文档，未调用媒体生成或新的LLM样片。
- 569个App lib/test文件的聚合摘要与任务前完全相同。

## 限制与资源成本

用户限额保持：文件20MiB、消息最多10份/50MiB、图片合计20MiB、PDF/PPT最多100页/张，OCR和模型文字预算不变。转换内部PDF输出40MiB、Kit40秒、外层45秒终止整个进程组；后台仍为单并发。

官方WASM的资源成本高于旧系统进程：独立冷启动峰值约1GiB内存并使用约595MiB交换，DOC/PPT约7–10秒；生产公网样本约9/11秒。继续限制MemoryMax=1GiB，并新增MemorySwapMax=768MiB，保留CPU/Tasks/FSIZE、禁网络、AF_UNIX、NNP、凭据与用户状态隔离。复杂文档仍可能触发已有超时／资源边界，不能把允许的文件体积当成必定能在时间窗口内完成的保证。

## 改动文件

```text
deploy/harness/README.md
deploy/harness/popi-document-converter.service
deploy/harness/prepare-document-runtime.sh
services/agent/local/document-converter-daemon.py
services/agent/local/document-office-convert.mjs
services/agent/local/document-office-convert.test.mjs
services/agent/local/document-parser.mjs
services/agent/local/document-parser.test.mjs
```

备份：`/var/backups/popi-harness-20261026T060241Z/`。本次无存储格式变更；回滚应切回备份记录的 release 和转换服务单元，再启动Harness，保留发布后的用户状态，不用旧store覆盖新消息或素材。Web及客户端安装包均不需要回退。

私有证据目录：`.omx/state/official-office-reuse/`，包含基线、官方spike、资源/取消/超时、源码摘要、369项Linux测试、SDK M0、HTTP读回和发布记录。
