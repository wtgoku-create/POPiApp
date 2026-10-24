# 本地开发

本文面向 `dev-mockui` 分支。项目使用 Flutter `3.44.9 stable`，与 CI
保持一致。本机为本项目准备的 SDK 位于 `/Users/jiajia/SDK/flutter`。

仓库提供 `tool/dev.sh` 作为统一入口。脚本会依次查找 `FLUTTER_ROOT/bin`、`PATH`
和 `~/SDK/flutter/bin`，因此不要求修改全局 `PATH`。首次拉取代码后执行：

```bash
./tool/dev.sh doctor
./tool/dev.sh setup
```

仓库已跟踪 Android、iOS、Web、macOS、Linux 和 Windows 平台目录，不需要执行
`flutter create .`。`setup` 会安装 Dart 依赖并生成国际化代码。

## 统一的 macOS 与 Web Harness

日常本机开发默认使用同一个 `lib/main_harness.dart` 和 `config/env/harness.json`，两端均读取
`127.0.0.1:3084` 的权威会话与自有图片、视频，不复制各自的离线样例数据。先按下方说明
启动 Agent 服务，再选择客户端：

```bash
./tool/dev.sh                 # 默认 Web，127.0.0.1:7357
./tool/dev.sh harness         # 同上
./tool/dev.sh macos           # 原生 macOS POPi，同一入口与数据
./tool/dev.sh build-web       # 构建 Harness Web
```

VS Code 使用 `POPi - macOS Harness` 或 `POPi - Web Harness`。两者使用同一套配置；
原生端发送配置中的允许 Origin，Web 由浏览器自动发送 Origin。macOS 只为本机资源开启
`NSAllowsLocalNetworking`，未开启全局任意 HTTP 访问。回到前台、切换会话/素材页签、
从聊天返回时会刷新服务端数据；聊天或设置覆盖首页期间暂停首页自动同步，打开会话前
等待已有同步完成并重新核实会话仍存在。客户端本地缓存用于显示恢复，不承担跨端数据同步。

这是进入首页时的同步，不是所有已打开页面的实时推送。另一端更新后，可返回首页、
切换会话/素材页签或重新将客户端切到前台以读取最新数据。

macOS 与 Web 的 SharedPreferences 属于各自平台，服务器的 session/asset ID 才是共同
依据。切换后原 `popi_ui_demo_v1` 及其备份仍保留；需要离线展示时显式运行以下 Demo。

## 运行离线 Demo

离线 UI 演示使用显式的 `lib/main_demo.dart`：

```bash
# 离线 Web Server，监听 127.0.0.1:7357
./tool/dev.sh demo
# 离线 Web 构建
./tool/dev.sh build-demo-web

# Chrome（支持热重载）
./tool/dev.sh demo -d chrome

# macOS 桌面端
./tool/dev.sh demo -d macos
```

默认 Web Server 使用兼容模式，修改代码后在运行终端按 `R` 热重启。显式选择 Chrome
或原生设备时支持 Flutter 热重载。

Demo 的首页、聊天流程和素材库使用离线 fixture，可在没有真实 Agent 服务时开发和
演示。回复、图片、音频、视频以及“生成”结果都是固定的本地样例，不会执行真实生成或
支付。点击头像后进入的个人资料和账号相关页面仍使用开发环境后端，因此会受到登录状态、
网络和服务可用性的影响。

当前参考交互从会话页 `+` 开始：手机和桌面均直接打开“创建新的 Popi”，填写最多 10 个
字符的名称、可选职责、生肖头像与背景颜色，一次确认后创建并进入聊天，名称同时作为会话
初始名称。取消不保存，创建失败保留完整表单。会话列表支持置顶及菜单
操作，可取消置顶、重命名和删除；设置页最多关联 5 个角色和 5 个成员，每个成员的能力
开关彼此独立，工作方式等配置也会保存在本地。离线 Demo 中，这些配置只驱动 UI 和本地
状态；下方 Harness 入口会把配置保存到服务端，并用于后续执行。

语音按钮使用系统或浏览器语音识别，录入后由用户确认发送。离线素材上传仍使用内置
样例：关闭 Sheet 不会写入资产库，确认时整批原子保存；保存失败会保留全部已选项，允许
直接重试，不会先写入部分素材再产生重复项。

浏览器适合验证 UI、聊天交互和 Mock 内容预览。素材下载、系统分享等原生集成请在
macOS、iOS 或 Android 上验证，不要以浏览器结果代表原生行为。macOS/iOS 开发还需要
CocoaPods；iOS 验证还需要在 Xcode 中安装对应的 Simulator Runtime。

更完整的 Demo 操作范围和重置方式见 [UI Demo](ui_demo.md)。

需要绕过快捷脚本或排查参数时，可直接使用环境脚本：

```bash
dart run tool/flutter_env.dart development run -t lib/main_demo.dart -d chrome
dart run tool/flutter_env.dart development run -t lib/main_demo.dart \
  -d web-server --no-web-experimental-hot-reload \
  --web-hostname 127.0.0.1 --web-port 7357
dart run tool/flutter_env.dart development run -t lib/main_demo.dart -d macos
```

## 用现有界面连接本机 Harness

需要从空会话开始验证真实文字对话时，使用独立入口 `lib/main_harness.dart`：

```bash
# Agent 服务终端（固定 Node 22.22.3）
cd /Users/jiajia/Documents/ChatGPT/PAPP
/Users/jiajia/.hermes/node/bin/node services/agent/local/server.mjs

# Flutter 终端（Web/macOS 选择其一，或各开一个终端同时运行）
cd /Users/jiajia/NewPopiApp
./tool/dev.sh harness
# 另一终端：./tool/dev.sh macos
```

Web 地址仍是 `http://127.0.0.1:7357/`，本地 Agent API 是
`http://127.0.0.1:3084`。公开客户端配置位于 `config/env/harness.json`；模型密钥
继续由服务端官方 credentials 插件读取，不写入客户端环境文件，也不发送正式账号 Token
给本地桥接服务。服务端配置和运行说明见
[/Users/jiajia/Documents/ChatGPT/PAPP/services/agent/local/README.md](/Users/jiajia/Documents/ChatGPT/PAPP/services/agent/local/README.md)。

这个入口复用现有会话、聊天、设置和素材页面布局，会话和素材从空状态开始。原离线 Demo
快照保存在 `popi_ui_demo_v1_before_harness`，原 `popi_ui_demo_v1` 数据也保留；Harness
使用独立的 `popi_harness_demo_v1` 缓存，不会再填入七条样例会话。`./tool/dev.sh demo`
仍可回到原离线演示。

新建、重命名、归档、发送和历史快照由本地服务处理；回复来自锁定的 Harness SDK 与真实
DeepSeek 模型。浏览器通过短轮询观察实际运行状态和已提交消息，不再模拟逐字输出。
刷新或关闭页面不会取消服务端任务；返回同一会话可继续查看。每次执行使用该会话独立的
工作目录和 Harness home。单成员对话按成员身份通过官方 `resumeSession` 续接私有历史；
群聊回合从服务端的公开历史构建上下文。

新建会话、发送消息、停止、刷新后恢复以及历史续接继续走真实 Harness 路径。成员、角色
设定、全局与成员能力、工作方式、当前成员、创作方向和定位改为由服务端保存，客户端缓存
用于恢复显示。新配置从 `configRevision: 1` 开始；旧会话以 `legacy`、版本 `0` 兼容迁移。
保存时携带预期版本，并发修改返回 `409 config_conflict`，保留编辑草稿供用户再次确认保存。

每次接受消息时，服务端固定当轮配置快照与版本，后续设置修改只影响下一轮。自动协作和
按需调用按配置的成员顺序安排回合，每位成员每轮最多执行一次；手动选择只调用当前成员。
多成员回合使用明确的回复或跳过决策，跳过后继续下一位，不生成空消息。后位成员能看到
此前群里的公开历史及本轮已经发表的回复，判断是否有补充或纠错。公开历史保留最近 40 条、
最多 24,000 个文字字符；当前用户输入单独提供。每个成员回合使用独立的 DSH 对话标识，
私有跳过决策和工具日志不会当成其他成员的公开发言。停止或执行失败会阻止后续成员继续。
群聊切回单成员、或切换当前唯一成员时，按该成员的公开历史游标补齐尚未看到的发言和
后台结果；各成员不共享私有 DSH 对话或工具日志。

DSH 的 `ask_user_question` 通过本地插件接入消息内问答卡片。单题单选点击选项即可提交；
多题、多选及补充回答使用确认按钮。卡片和答案随服务端快照保存，刷新或重新打开浏览器
仍可回答，提交后继续同一个运行和成员回合。答案接口沿用
`POST /api_agent/v2/sessions/:sessionId/questions/:questionId/respond`，携带题目修订、
动作、答案与请求幂等标识。提交失败保留选择及输入，通过原选项或确认按钮再次提交。

等待用户时运行状态为 `waiting_user`，客户端不以普通文字回复超时处理。停止会把未答卡片
标为已停止；重启 Agent 服务会将未答卡片标为已过期，并将运行标为中断。重启服务不会
自动重放问题或继续已经结束的工具调用。插件的内部答案通道使用每个进程独立的本机认证，
浏览器只访问现有 Agent API。

本机 DSH 的官方联网搜索在服务端私有 `model.json` 中通过 `"web": {"enabled": true}`
开启，复用现有 DeepSeek 官 key 的凭证引用。启用后文字和媒体会话均可调用 `web_search`
与 `web_fetch`，分别走官方 Search/Fetch API；不需要把 key 或搜索配置放入客户端。
`GET http://127.0.0.1:3084/api_agent/v2/capabilities` 的 `web` 字段可检查工具是否实际绑定。
实时信息回复应附搜索来源，网页读取结果仅作为外部资料；具体配置与验证见
[本地服务说明](/Users/jiajia/Documents/ChatGPT/PAPP/services/agent/local/README.md#official-web-search-and-page-retrieval)。

DSH 上下文装配成员和角色的实际文字设定；只选角色头像或名称不代表角色档案已就绪。
媒体工具同时检查全局能力与成员能力，并绑定本回合成员身份。视觉理解单独受 `vision`
能力控制；音频能力覆盖 TTS 和音乐。普通回复带成员、运行和配置版本信息，App 按成员
显示昵称及头像，旧的无身份消息继续按 POPi 显示。新昵称优先使用当前设置，成员移除后
可以从消息保存的名字恢复身份。

图片链路已接入服务端任务和自有文件：DSH 提交任务后，文字可以先完成，独立后台 worker
继续查询原任务并保存图片。带成员身份的图片、视频任务完成入库后，会在原会话新增一条
负责成员的结果消息，同任务的多个结果合并展示；重复查询或重启不会重复发消息，也不会
触发新一轮讨论。旧的无成员身份任务仍兼容回填原回复。聊天消息与素材库引用同一个资产 ID，
通过本机 Agent API 读取已保存的字节；不依赖内置样例或临时供应商链接展示。刷新、关闭浏览器或重启桥接后，会继续
跟进原任务，已保存图片仍能读取。界面区分生成中、保存中、完成和失败，不把文字结束当作
图片已经入库。用户点击停止会结束当前会话独占的文字执行进程，其他会话不受影响；已经
提交的媒体任务不会因此取消。异常中断、结果未知的提交不会由服务重启自动重发。

当前服务端配置使用 Image2.5（`image-2.5-official`，目录显示名 `Image2.5 Flare官方`），默认
1k、medium、1:1、PNG；视频使用 Seedance2.5（`seedance-2.5`），默认 480p、30 秒、
`draft: false`。预检读取实时模型目录，不产生生成费用。配置、服务端密钥和参数说明见
[DSH 多模态配置](/Users/jiajia/Documents/ChatGPT/PAPP/services/agent/local/MULTIMODAL.md)。

本地供应商 fixture 已验证配置版本、跨进程任务跟进和图片入库；随后从 Web 发起的真实
Image2.5 单图任务也已完成：1024×1024 PNG 已进入聊天和素材库，浏览器下载及重启恢复通过。
对应证据位于 PAPP 的 `artifacts/popi-single-image-real-v1/verification.json`。
后续真实 Seedance2.5 参考图视频也已通过：480×854、30.08 秒、原生音轨，进入原聊天与
素材库，网页播放、拖动进度、下载哈希和重启恢复均已验证，见
`artifacts/nanji-cafe-video-v1/verification.json`。视频以私有文件保存，内容接口支持 HEAD/Range；
Web 下载交给浏览器，Web 分享单独限制为 32 MiB。无封面时显示中性播放占位与实际时长。
资产页左上角的上传入口现在支持系统多文件选择，并将 PNG/JPEG/WebP 图片、MP4 视频、
TXT/MD 脚本和 MP3/WAV/M4A 音频保存到本机资产库；刷新和服务重启后仍可读取。
大小上限分别为图片 20 MiB、视频 128 MiB、脚本 2 MiB、音频 32 MiB。上传失败保留所选
文件，已成功文件不会在重试时重复提交；重复选择相同内容和名称也会复用资产标识。
文件上传入库与后续参考图生成是不同能力；把原图传给模型、独立配音/音乐和正式作品保存
仍未完成对应的产品交付链路。
网站上传接口使用网站登录凭证，API Key 探测返回 `401`，原图参考传输尚未接通，不能把
收到参考图描述为已完成参考图生图或角色一致性验收。Harness 素材库不显示离线 Demo 的样例
选择，也不会用内置素材冒充上传成功。

## 运行正式入口

需要联调登录、账号、会话等真实开发接口时，运行 `lib/main.dart`。快捷命令默认启动
开发环境 Web Server：

```bash
./tool/dev.sh app
```

等价的底层命令为：

```bash
dart run tool/flutter_env.dart development run -t lib/main.dart \
  -d web-server --no-web-experimental-hot-reload \
  --web-hostname 127.0.0.1 --web-port 7357
```

开发环境的公开配置位于 `config/env/development.json`。如需覆盖本机地址或开关，复制为
`config/env/development.local.json`，再通过环境变量交给快捷脚本：

```bash
POPI_ENV_FILE=config/env/development.local.json ./tool/dev.sh app
```

`*.local.json` 已被 Git 忽略。环境文件只保存可公开的客户端配置，不要写入 App Secret、
私钥、服务端密钥或个人 Token。底层环境脚本也可以直接接收该文件：

```bash
dart run tool/flutter_env.dart config/env/development.local.json run -t lib/main.dart -d chrome
```

## 检查与构建

提交前执行与 CI 对齐的检查和测试：

```bash
./tool/dev.sh test
```

构建本机 Harness Web 包：

```bash
./tool/dev.sh build-web
```

`test` 先运行静态检查，再使用选定的环境配置运行测试；`build-web` 使用 Harness 环境构建
`main_harness.dart`，产物位于 `build/web/`；离线 Demo 使用 `build-demo-web`。已经把 Flutter
加入 `PATH` 时，也可以直接执行或排查：

```bash
flutter analyze
dart run tool/flutter_env.dart development test
dart run tool/flutter_env.dart harness build web -t lib/main_harness.dart
```
