# DSH 原生附件与图片能力复用 · 2026-10-26

服务端已发布 `20261026T064902Z`：<https://124.222.185.31/>。
Web仍为 `20261026T042201Z`，Mac/iOS6101安装包继续使用原界面与API；本次不重新打包客户端。569个App lib/test文件与任务前聚合摘要一致。

## 验证后确定的边界

DSH确实已有原生附件存储、浏览器上传、图片解码/规范化和请求变体能力。本轮按karpathy-guidelines，只替换能保持现有产品合同的叶子。

| 原生能力 | 本轮结论 |
|---|---|
| saveImage / prepareImageFile | 输出规范化图片，可能旋转、缩放、改MIME/SHA、去metadata；不能充当产品原件 |
| saveFileStream / readFileStream | 原字节可保留，但使用内容摘要ID、原生路径和hardlink，完整流摘要在EOF验证；不提供原产品UUID/MIME/HEADRange合同，保持现有原件库 |
| client-file-upload | Session-owned暂存凭证，不是Flutter统一REST或全局素材库的直接替代；本轮不迁移 |
| readImageRequest | 当前SDK发送模型图片时已经使用，继续复用，不额外叠加一层 |
| validateImageFile | 可作为图片完整解码/临时规范化校验；无硬超时/取消，因此仅在可终止子进程内调用 |

## 实际替换

保留原PNG IEND、JPEG EOI、WebP容器长度检查和inspectImage原始metadata，图片解码叶子改为锁定 `dsh-attachment-local@0.2.1-rc.2` 的官方 `validateImageFile`。

固定Node helper通过该官方包自身的require上下文加载其精确依赖 `sharp@0.35.5`，用header-only metadata补齐未按EXIF旋转的raw宽高校验，再由DSH执行完整解码。公开原件metadata仍来自原inspectImage；helper不写store、不返回normalized bytes/ref、不修改原图。Sharp官方说明见 [Input metadata](https://sharp.pixelplumbing.com/api-input/)。

父进程保持15秒硬期限、SIGKILL整个进程组、64KiB输出、禁shell和最小环境。内容错误仍为400 asset_content_invalid，运行时缺失/版本漂移、异常退出和输出溢出以503 image_validator_unavailable失败，原输入和素材保留。

用户文件、assetId、幂等、原字节/SHA/MIME/尺寸、鉴权、URL、HEAD/Range及缩略图流程保持。音视频继续原FFprobe，文档/OCR和上轮官方Office转换均未改，也未重启Office服务。

## 限额不变

- 上传/素材库图片：20MiB、单边16384、100M pixels。
- 发给模型的图片：单边8192、64M pixels，图片合计20MiB；消息最多10附件/总50MiB，沿原发送层检查。
- DSH默认临时规范化策略为4M pixels/8192/4MiB编码目标，仅用于验证，结果丢弃，**不会把用户上传限额改为4MiB或缩小原件**。

## 验证

- 任务前52项上传/原件/缩略图/消息回归通过。
- 原生API13/13、metadata桥11/11；证明EXIF原始100×60与规范化60×100不能混用，原生会接受缺IEND PNG，因此必须保留原尾部guard。
- 独立四并发100M ICC图：约6.3秒、1.54GiB峰值、swap/OOM/残留均0。选择DSH默认规范化策略；同大尺寸规范化对照更耗资源，未采用。
- 实际候选父函数+helper在3GiB/CPU200%/Tasks256下四并发：clean约1.85秒、ICC约6.27秒、1.26GiB峰值、无swap/max/OOM；原图SHA不变。
- Linux全套372/372、无skip，SDK M0通过；上传/原件/缩略图/消息定点55项通过。测试用Office非timeout fake-shell预算从1秒改5秒以避免并发调度假失败，生产40/45秒和0.05秒timeout测试不变。
- 实际API九类图片：三格式、透明、EXIF、16-bit、动画WebP、ICC、极端比例均保持raw bytes/SHA/MIME/encoded尺寸；HEAD/Range和幂等通过，缺IEND拒绝。QA API重启后9个原件仍可读。
- PDF/DOCX/PPTX/DOC/PPT/扫描PDF回归六份全部通过，原件和提取文字可读、OCR继续启用。
- 公网认证后的PNG/JPEG EXIF/WebP上传、原件、缩略图、HEAD/Range、ID幂等通过；未登录401、内部路径404、跨源403。
- 发布前idle/上传检查、备份并仅切换API；保留8个会话、26项既有素材、凭据和Web版本，Office服务PID保持。公网烟测随后新增三个明确命名的自制测试图，未调用模型或生成媒体样片。

## 有意记录的差异与限制

合法动画WebP此前被FFprobe误拒，现在可通过原生首帧校验并保留原动画字节；模型请求仍由DSH按首帧处理。本次没有扩展GIF/其他上传格式，也未承诺所有解码器对任意畸形图具有完全相同的恢复行为。缩略图沿原best-effort路径，部分动画/极端比例可能不生成缩略图，原件保持可读。

官方校验包含临时规范化，可能比旧单纯解码更耗CPU；不能把小图或100M样本的时间当成所有复杂图的保证。原15秒期限、四上传并发及API3GiB资源边界继续保留。

## 改动文件

```text
services/agent/local/document-office-convert.test.mjs
services/agent/local/image-validation-helper.mjs
services/agent/local/uploaded-assets.mjs
services/agent/local/uploaded-image-validation.test.mjs
```

其中生产代码仅图片helper与上传解码叶子；另两个文件为回归测试，无新SDK/npm/Flutter依赖或数据迁移。

备份：`/var/backups/popi-harness-20261026T064902Z/`。存储格式不变，回滚只需在空闲时切回前一backend symlink并重启API，不恢复旧store覆盖新用户数据；Web及Office服务不需切换。私有证据在 `.omx/state/native-attachment-reuse/`。
