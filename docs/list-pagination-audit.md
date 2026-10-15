# 列表分页检查

检查范围：Flutter 中带 `page` / `pageSize` 的列表请求，以及 Repository 中循环取页的调用链。日期：2026-10-14。

## 本次修复

会话侧边栏 `/api_agent/v2/sessions` 原来每页请求 100 条，`ApiSessionRepository.list` 循环拉取所有页后才返回，侧边栏只有下拉刷新，没有网络分页的上拉加载。

现改为每页 20 条，只请求当前页；上滑接近底部时追加下一页，按服务端 `pageCount` 停止。翻页期间保留已有数据，失败通过 Toast 提示并允许再次上拉。刷新、账号切换和会话变更取消过期请求；会话变更后从第一页重新核对，避免基于旧偏移漏掉数据。顶部新项目按钮保持固定。

相关文件：`lib/features/session/data/session_repository.dart`、`lib/shared/providers/session_provider.dart`、`lib/shared/widgets/popi_drawer_sessions.dart`。

## 其他同类问题的修复

以下调用链现已移除全量预取，统一每页 20 条，由页面或弹层滚动加载后续页。

| 场景 | 接口 | 当前行为 | 代码位置 |
| --- | --- | --- | --- |
| IP 账号管理 | `/api_client/agent/v2/accounts` | 每页 20 条，滚动追加，删除后核对分页偏移 | `IpAccountRepository.list`、`IpAccountsLivePage._load` |
| 常驻角色选择 | `/api_client/agent/v2/roles` | 每页 20 条，筛选后为空仍保留服务端下一页信息 | `IpAccountRepository.availableRoles`、`IpAccountRolesSheet._load` |
| 聊天画风库 | `/api_client/agent/v2/role-templates` | 每页 20 条，滚动追加，已选画风独立保留 | `ApiSessionRepository.roleTemplates`、`ConversationStyleLibrarySheet._load` |
| 创作页项目/账号选择 | `/api_client/agent/v2/accounts` | 每页 20 条，滚动追加，选择状态独立保留 | `ProjectRepository.listProjects`、`RoleProjectSheet` |
| 旧项目会话列表 | `/api_agent/v2/sessions?accountId=…` | 每页 20 条，各项目会话滚动区域追加并按需构建条目 | `NetworkAgentApi.projectSessionsPage`、`ProjectRepository.listSessions` |

项目选择确认直接通过 `/api_agent/v2/sessions/by-account/:accountId` 查询账号唯一绑定会话，仅明确返回绑定不存在时创建会话，不再为了打开项目拉取全部会话。后端 `getAccountSession` 定义了唯一绑定关系。

分页期间保留已有行，避免重复请求，失败通过 Toast 提示并允许后续滚动重试；页面关闭、分类切换和账号切换取消过期请求。长列表使用 builder，旧侧边栏保留离屏项目的已加载分页状态。

## 没有发现相同全量预取的问题

| 场景 | 每页数量 | 继续加载方式 |
| --- | --- | --- |
| 作品库、作品选择 | 20 | 滚动加载下一页 |
| 角色库 | 20 | 滚动加载下一页 |
| 创作角色选择 | 30 | 滚动加载下一页 |
| 通知 | 20 | 滚动加载下一页 |
| 积分明细 | 20 | 滚动加载下一页 |
| 教学课程 | 20 | 滚动加载下一页 |
| 邀请码、邀请记录 | 20 | 加载更多操作 |
| IP 账号历史、档案 | 20 | 加载更多操作 |
| 设备相册 | 60 | 本地相册按页读取，不是后端接口 |

套餐、积分包、模型和分类等不提供分页的配置接口，不归为本次的分页预取问题。

## 未接入的代码

`IpAccountRepository.resources` 已改成每次仅读取请求的档案页，默认每页 20 条，返回页信息；生产代码中没有找到调用点，仅测试调用。`NetworkApi.ipAccountResourcesPage` 也改为默认每页 20 条，允许调用方传入页大小，目前没有调用点。

`PopiDrawerProjects` 已不用于当前会话侧边栏；其 `projectsProvider` / `projectSessionsProvider` 已接入分页，避免旧组件再次启用时恢复全量预取。

## 验证结果

- `flutter pub get`、`flutter analyze --no-pub` 和 `git diff --check` 通过。
- `flutter test --no-pub --concurrency=1 --no-track-widget-creation --reporter expanded`：全量 1137 项通过。
- 补充桌面滚轮空页加载后，账号管理、角色选择、画风库、项目选择和旧侧边栏共 42 项界面回归通过，包含新增滚轮用例。
- 覆盖单页请求、最后一页停止、重复请求保护、重复 ID 合并、失败恢复、刷新取消、账号切换、筛选空页和跨页选中状态。
- 本次未提交。
