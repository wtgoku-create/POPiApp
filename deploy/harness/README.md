# POPi 测试服务器

当前入口：**https://124.222.185.31/**。手机浏览器和桌面浏览器使用同一份最新 Flutter 页面。
登录账号与密码保存在服务器 `/root/.popi-harness-web-access.json`，本机交付副本位于
`.omx/state/test-server/web-access.json`，权限均为 `0600`。不要将它们放入公开配置或 Web 包。

## 运行结构

- Ubuntu 24.04，官方 Node **22.22.3**，DSH **0.2.1-rc.2**。
- `/opt/popi-harness/releases/<release>`：工作区源代码、Linux 安装的锁定 SDK 和验证记录。
- `/opt/popi-harness/current`：当前服务版本；`popi-harness.service` 以独立用户运行。
- `/var/lib/popi-harness`：独立测试会话、上传文件及运行状态，不随发布覆盖。
- `/etc/popi-harness`：模型配置与最小 provider 凭证；不复制本机浏览器登录记录。
- `/srv/popi-web/releases/<release>` 和 `current`：静态页面版本与原子切换入口。
- `popi-access.service`：独立用户运行的测试登录门禁，只读 `/etc/popi-access/access.json`。
- Harness 和登录服务仅监听 `127.0.0.1:3084/3085`；Caddy 提供公网 HTTPS。

Caddy 保留既有站点，只增加 POPi 的独立 IP 站点。公网 IP 证书使用 Let's Encrypt
`shortlived` profile，由 Caddy 自动续期；`default_sni` 让不发送 SNI 的 IP 客户端也能验证证书。
网页登录使用签名的 `Secure`、`HttpOnly`、`SameSite=Strict` Cookie，24 小时有效。
登录表单采用 `same-origin` Referrer Policy，以保留同源表单提交的 Origin 校验。
`/_internal`、`/verify` 和 Git 路径不会转发到内部服务。

## 构建与首次部署

从应用工作区运行；打包读取当前工作树，包含尚未提交的页面修改：

```sh
flutter pub get
flutter analyze
flutter test --timeout 60s
dart run tool/flutter_env.dart harness_remote build web --release \
  -t lib/main_harness.dart --no-pub --output build/web-test-server

python3 deploy/harness/package-source.py \
  --harness-source /path/to/PAPP --output .omx/state/test-server
node deploy/harness/prepare-private.mjs \
  --harness-source /path/to/PAPP --output .omx/state/test-server/private
```

`config/env/harness_remote.json` 仅包含公开地址和开关。正式账号 Token 不会发送给测试
Harness，模型密钥也不会编译进客户端。远程构建独立输出，保留本机 `build/web` 和 7357
开发服务。发布前核对源代码摘要与 `main.dart.js` 摘要，并生成 `deployment.json`。

通过 SSH 传输 source release、私有配置归档和静态页面；私有配置归档只能包含
`model.json`、`huimengi.json`、`.credentials.yaml`、`service.env`。服务器上依次运行：

1. `prepare-server.sh`：创建 POPi 专用目录，校验官方 Node 下载摘要和媒体工具。
2. `install-release.sh <release>`：Linux `npm ci --ignore-scripts`、显式 seal、后端测试和 SDK M0。
3. `prepare-access.py`：创建独立登录用户与服务，私有签名密钥在重发时保留。
4. `prepare-site.py <release>`：验证带认证的 Caddy 配置，不立即切换已有入口。
5. `publish-site.py <release>`：核对健康状态与页面摘要、备份原 Caddy 配置，再切换 Web 和 reload。

源代码发布包必须包含 `.patch.yml` 文件。macOS 的 `node_modules` 和平台锁不能直接拿到
Linux 启动；Linux 必须自行安装依赖并 seal。SDK 路径指纹会在运行时继续校验。

当前 `install-release.sh` 对已运行的 Harness 只完成 staging 后退出 `3`，不会覆盖其私有
配置或重启活动对话。更新服务前先核对正在运行的任务、备份 `/var/lib/popi-harness`，再显式
安排版本切换。只更新页面可独立构建、上传并切换 Web，不需要重启 Harness。

## 验证与运维

```sh
systemctl status popi-harness popi-access
ss -ltnp
curl http://127.0.0.1:3084/health
journalctl -u popi-harness -u popi-access
```

验证至少包括：未登录 API 返回 `401`、内部路径返回 `404`、跨源写入返回 `403`；登录后
页面摘要与构建一致、一次文字回复、上传读取/HEAD/Range，以及服务重启后的原会话和文件
恢复。测试文字不会触发图片、视频或音频生成。

Web 入口、脚本和可变 API 采用 `Cache-Control: no-store`，避免更新后仍展示旧页面。
内容寻址的原始素材、图片缩略图与视频首帧沿用 Harness 返回的
`private, max-age=31536000, immutable`，
使同一登录缓存命名空间可以复用本机文件；登录会话变化时客户端使用新的缓存键，不复用旧会话内容。
服务由 systemd 开机启动。原 Caddy 配置及发布记录保留，回滚不要删除独立状态目录。

这是单用户共享测试环境，尚不提供生产账户隔离。原生远程 Harness 构建使用独立登录页，
登录会话存入 Secure Storage，24 小时到期后重新登录并保留聊天草稿。Cookie 仅用于同源
`/api_agent/`，不与正式账号 Token 混用，也不写入 URL、图片缓存键或安装包。受保护图片
禁止重定向；原生受保护音视频通过有大小限制的临时文件播放，取消和退出时清理。
已安装 App 不会随网页发布自动更新；手机签名分发参见 `docs/mobile-testing.md`。
上传参考图仍需遵守现有云端可访问性限制。
