// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'POPi';

  @override
  String get hideKeyboard => '收起键盘';

  @override
  String get roleGuideTitle => '从角色出发';

  @override
  String get roleNotReadyForVideo => '角色档案或参考图尚未就绪';

  @override
  String get roleRequestFailed => '创作请求失败，请重试';

  @override
  String get roleStoryRequestFailed => '选题请求失败';

  @override
  String get roleLoadingStories => '正在推荐故事...';

  @override
  String get roleNoStories => '暂无推荐故事';

  @override
  String get roleAccountFallbackTitle => 'IP账号';

  @override
  String get roleNoVideoModels => '暂无可用视频模型';

  @override
  String get roleModelConfigured => '已配置生成模型';

  @override
  String get roleTaskPaused => '创作已暂停';

  @override
  String get roleStatusPausing => '正在暂停';

  @override
  String get roleTaskPausing => '任务正在暂停...';

  @override
  String get roleTaskCanceling => '任务正在取消...';

  @override
  String get roleStatusPaused => '已暂停';

  @override
  String get roleStatusCanceling => '正在取消';

  @override
  String get roleGenerationPausedDescription => '当前方案已保留，可以继续创作';

  @override
  String get chatTaskCanceling => '取消中，等待当前阶段完成';

  @override
  String get rolePauseProduction => '暂停创作';

  @override
  String get roleResumeProduction => '继续创作';

  @override
  String get roleConfirmVideo => '确认生成视频';

  @override
  String get roleGuideDescription => '选择至多5个角色\n组建一个新项目会话';

  @override
  String get roleCastTitle => '选择出场角色';

  @override
  String get roleCastDescription => '选择你项目内\n至多3个角色参演视频：';

  @override
  String get roleTopicTitle => '匹配选题';

  @override
  String get roleTopicDescription => 'POPi根据角色人设\n推荐合适的3个选题';

  @override
  String get roleProductionTitle => '制作视频';

  @override
  String get roleProductionDescription => '选择模型与参数\n让你的故事栩栩如生';

  @override
  String get roleCreateProject => '创建项目';

  @override
  String get roleConfirmSelection => '确认选择';

  @override
  String roleSelectionLimit(int count) {
    return '最多选择$count个角色';
  }

  @override
  String get removeRole => '移除角色';

  @override
  String get removeAsset => '移除资产';

  @override
  String assetSelectionLimit(int count) {
    return '最多选择$count个素材';
  }

  @override
  String get chatRolePrompt => '请参考所选角色进行创作。';

  @override
  String get roleGuideViewMore => '查看更多';

  @override
  String roleSelectedCount(int count) {
    return '（已选$count个角色）';
  }

  @override
  String get roleChooseCast => '选择TA们参演';

  @override
  String get roleSelectProjectFirst => '请先选择项目角色';

  @override
  String get roleSelectCastFirst => '请先选择出场角色';

  @override
  String get roleProjectLimit => '至多选择5个项目角色';

  @override
  String get roleCastLimit => '至多选择3个出场角色';

  @override
  String roleProjectName(String name) {
    return '$name的项目';
  }

  @override
  String roleProjectCount(int count) {
    return '共有$count个角色';
  }

  @override
  String roleCastCount(int count) {
    return '共$count个角色';
  }

  @override
  String get roleChooseStory => '选择这个故事';

  @override
  String get roleRefreshStories => '都不满意，换一批';

  @override
  String get roleReconfirmVideo => '重新确认生成视频';

  @override
  String get rolePreviousStory => '上一个故事';

  @override
  String get roleNextStory => '下一个故事';

  @override
  String get roleStoryOverview => '故事概况';

  @override
  String get roleSwitchProject => '切换项目';

  @override
  String get roleMyProjects => '我的IP项目';

  @override
  String get roleEditProjectRoles => '修改项目角色';

  @override
  String get roleViewProfiles => '查看角色档案';

  @override
  String roleProfilePage(int index, int total) {
    return '角色档案 $index/$total';
  }

  @override
  String get roleFullProfile => '查看完整角色档案';

  @override
  String get roleCollapseProfile => '收起完整角色档案';

  @override
  String roleFullProfileVersion(String version) {
    return '查看完整角色档案$version';
  }

  @override
  String get rolePreviousProfile => '上一个角色档案';

  @override
  String get roleNextProfile => '下一个角色档案';

  @override
  String get roleDetailedStory => '详细故事';

  @override
  String get roleStoryDevelopment => '情节发展';

  @override
  String get roleStoryContent => '主要内容';

  @override
  String get roleProduceVideo => '制作视频';

  @override
  String get roleStartCreating => '开始创作';

  @override
  String get roleViewPlan => '查看方案';

  @override
  String get roleGeneratingTitle => '努力生成中...';

  @override
  String get roleGeneratingDescription => '你可以在此界面停留\n或去会话查看方案';

  @override
  String get roleGeneratedTitle => '生成成功！';

  @override
  String get roleGeneratedDescription => '去会话修改生成\n或和Agent聊聊新思路';

  @override
  String get roleGenerationFailedTitle => '生成未完成';

  @override
  String get roleGenerationFailedDescription => '保留当前方案\n重试或调整后继续';

  @override
  String get roleGenerationCanceledTitle => '已停止制作';

  @override
  String get roleGenerationCanceledDescription => '当前方案已保留\n调整后可以重新制作';

  @override
  String get roleTaskRunning => '任务正在生成...';

  @override
  String get roleTaskCompleted => '任务已完成';

  @override
  String get roleTaskFailed => '生成失败，请重试';

  @override
  String get roleTaskCanceled => '任务已停止';

  @override
  String get roleTaskExecuting => '执行中';

  @override
  String get roleStatusCompleted => '已完成';

  @override
  String get roleStatusFailed => '失败';

  @override
  String get roleStatusCanceled => '已停止';

  @override
  String get roleStageCharacters => '理解人设';

  @override
  String get roleStageScript => '撰写剧本';

  @override
  String get roleStageStoryboard => '编排分镜';

  @override
  String get roleStageVideo => '合成视频';

  @override
  String get roleStageReview => '检查结果';

  @override
  String get roleWorkGenerating => '作品努力生成中...';

  @override
  String get roleStopProduction => '停止制作';

  @override
  String get roleStopProductionTitle => '停止当前制作？';

  @override
  String get roleStopProductionDescription => '停止后会保留角色、故事和模型参数，可以重新制作。';

  @override
  String get roleKeepGenerating => '继续等待';

  @override
  String get roleContinueCreating => '继续创作';

  @override
  String get roleChatInSession => '去会话聊聊';

  @override
  String get roleProjectSession => '项目会话';

  @override
  String get roleScriptContent => '脚本内容';

  @override
  String get chatVideoProgress => '视频生成进度';

  @override
  String get chatStoryboardReview => '分镜脚本已完成，待确认生成视频';

  @override
  String get chatTaskPausing => '暂停中，等待当前阶段完成';

  @override
  String get chatStageGenerateVideo => '生成视频';

  @override
  String get chatStageInspectResult => '检测结果';

  @override
  String get roleStoryboardContent => '分镜视频提示词';

  @override
  String roleStoryboardShot(int index, String duration) {
    return '镜头 $index · $duration 秒';
  }

  @override
  String get roleVideoModelPrompt => '视频模型提示词';

  @override
  String get videoFullscreen => '全屏播放';

  @override
  String get rolePreviewNotice => '交互演示 · 不消耗积分';

  @override
  String get rolePreviewCover => '示例封面';

  @override
  String get roleEstimatePending => '选择模型与参数后查看积分预估';

  @override
  String get roleEstimatePreview => '积分以正式生成时的报价为准';

  @override
  String roleStoryPosition(int index, int total) {
    return '$index/$total';
  }

  @override
  String get roleExampleDevelopment1 =>
      '从迟迟无法落笔的毕业计划，到翻开朋友送来的画册，再到决定拍摄短片，角色在一次次回忆中找到自己的热爱。';

  @override
  String get roleExampleDevelopment2 =>
      '室友的反常举动引发调查，跟踪途中接连发生误会，最终在教室里的告别派对揭开惊喜。';

  @override
  String get roleExampleDevelopment3 =>
      '一次挫折让她习惯性的坚强出现裂缝。朋友从日常小事开始接住她，直到她愿意坦诚说出自己的疲惫。';

  @override
  String get roleExampleDevelopment4 =>
      '聚餐从轻松的玩笑转向认真倾听。她终于说出梦想，伙伴们也分享各自的心愿，一起定下一年之约。';

  @override
  String get roleExampleDevelopment5 =>
      '误会让两人疏远，伙伴的撮合适得其反。雨天的一次偶遇，让她们借一杯热可可说清了心里的委屈。';

  @override
  String get roleExampleDevelopment6 =>
      '搬家前的愿望清单只剩看日出。一路的小意外让大家互相照应，赶到山顶时，告别变成了下一次相聚的约定。';

  @override
  String get roleExampleContent1 =>
      '镜头一：窗边，笔尖停在空白的毕业计划上。\n镜头二：画册里的日常照片与校园回忆交错出现。\n镜头三：伙伴们举起相机，在夕阳下拍下短片的第一个镜头。';

  @override
  String get roleExampleContent2 =>
      '镜头一：室友悄悄离开，伙伴们探头张望。\n镜头二：一路跟踪，手忙脚乱地藏到门后。\n镜头三：教室门打开，合影与灯光映出惊喜派对。';

  @override
  String get roleExampleContent3 =>
      '镜头一：她坐在桌前，收起勉强的笑容。\n镜头二：早餐、等待和小纸条串起朋友们的关心。\n镜头三：伙伴围坐在一起，她终于放松地靠在朋友肩上。';

  @override
  String get roleExampleContent4 =>
      '镜头一：餐桌上的笑声渐渐安静，大家认真听她说话。\n镜头二：她写下梦想，伙伴们依次写下心愿。\n镜头三：纸条放进盒子，大家一起在封口写下一年后的日期。';

  @override
  String get roleExampleContent5 =>
      '镜头一：两人在走廊擦肩而过，没有说话。\n镜头二：小店窗外下着雨，热可可冒着白气。\n镜头三：坦诚交谈后，两人共撑一把伞离开。';

  @override
  String get roleExampleContent6 =>
      '镜头一：大家勾选愿望清单，指向最后的看日出。\n镜头二：忘带钥匙、走错路，一路笑着互相帮忙。\n镜头三：晨光里并肩站着，约好下一次相聚。';

  @override
  String get roleModelParameters => '模型/参数';

  @override
  String get roleModelPending => '模型/参数（待选择）';

  @override
  String get roleChooseParametersFirst => '请先选择模型与参数';

  @override
  String get roleVideoPreference => '视频偏好';

  @override
  String get roleImagePreference => '图片偏好';

  @override
  String get roleModelSelection => '模型选择';

  @override
  String get roleResolution => '分辨率';

  @override
  String get roleRatio => '比例';

  @override
  String get roleDuration => '时长';

  @override
  String get roleNoImageModels => '暂无可用图片模型';

  @override
  String get roleDurationAutomatic => '智能选择';

  @override
  String get roleDurationCustom => '自定义';

  @override
  String roleDurationSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String get roleDimensions => '尺寸';

  @override
  String get roleQuantity => '生成数量';

  @override
  String roleEstimatedPoints(int points) {
    return '预计消耗积分：$points';
  }

  @override
  String get roleModelSoraDescription => 'OpenAI 最新媒体生成模型,原生支持音视频同步输出';

  @override
  String get roleModelVeoDescription => '谷歌顶级视频模型，电影级画质，镜头级精准控制';

  @override
  String get roleModelJimengDescription => '字节跳动即梦AI，动态连贯，风格统一，图生视频高效出片';

  @override
  String get roleModelKlingDescription => '快手可灵视频模型，物理拟真自然，运镜流畅稳定，高效出片';

  @override
  String get roleModelViduDescription => '生数科技自研模型，万物可参考，特效 / 材质精准迁移';

  @override
  String get roleModelDiscount => '限时5折';

  @override
  String roleVideoPlanPrompt(
    String project,
    String roles,
    String cast,
    String title,
    String story,
    String model,
    String video,
    String image,
    int quantity,
  ) {
    return '请按以下配置制作视频。\n项目：$project\n项目角色：$roles\n出场角色：$cast\n选题：$title\n故事概况：$story\n视频模型：$model\n视频参数：$video\n图片参数：$image\n生成数量：$quantity';
  }

  @override
  String get roleExampleAlice => '爱丽丝';

  @override
  String get roleExampleErer => '尔尔';

  @override
  String get roleExampleHua => '花西冷少';

  @override
  String get roleExampleDoudou => '水獭兜兜儿';

  @override
  String get roleExampleConfused => '小迷糊';

  @override
  String get roleExampleStrawberry => '草莓';

  @override
  String get roleExampleQiqi => '奇奇蒂蒂';

  @override
  String get roleExampleMermaid => '人鱼小姐';

  @override
  String get roleExampleDescription => '叮叮当同桌、室友和毒舌闺蜜...';

  @override
  String get roleExampleStoryTitle1 => '毕业以后，才发现自己喜欢...';

  @override
  String get roleExampleStoryTitle2 => '室友的秘密计划';

  @override
  String get roleExampleStoryTitle3 => '今天，换我来保护你';

  @override
  String get roleExampleStoryTitle4 => '第一次勇敢说出心里话';

  @override
  String get roleExampleStoryTitle5 => '误会之后的一杯热可可';

  @override
  String get roleExampleStoryTitle6 => '一起完成的最后一件小事';

  @override
  String get roleExampleStory1 =>
      '他低着头，手里拿着笔，迟迟没有写下毕业后的计划。窗外的笑声让他想起那些一起熬夜赶作业的日子。朋友发现了他的犹豫，递来一本记录着日常小事的画册。原来，他一直喜欢的是用故事留住身边的人。他们决定一起拍摄毕业前的最后一支短片，把没说出口的话写进剧情，也给未来的自己留下一份勇敢的答案。';

  @override
  String get roleExampleStory2 =>
      '最近，室友总是神神秘秘地早出晚归。大家以为她遇到了麻烦，决定悄悄跟上去。一路上的误会让这次调查变得啼笑皆非。推开熟悉的教室门，他们才发现，室友正在准备一场属于所有人的告别派对。墙上贴满合影，每一张照片后面，都藏着她想说却没说出口的感谢。';

  @override
  String get roleExampleStory3 =>
      '平时总是照顾别人的她，在一次意外中失去了信心。伙伴们没有急着安慰，而是偷偷接过她每天完成的小事：留一份早餐、等一次晚归、记住一个小愿望。当她发现自己也可以被照顾时，终于放下了逞强的笑容。原来，陪伴从来不是一个人的责任。';

  @override
  String get roleExampleStory4 =>
      '一次普通的聚餐，让大家谈起了从未说出口的梦想。她本想像往常一样笑着带过，却在朋友的鼓励下，说出了自己真正想做的事。没有人嘲笑，也没有人催促。大家把各自的愿望写在纸上，约定一年后再一起打开，看看这次勇敢会带他们走向哪里。';

  @override
  String get roleExampleStory5 =>
      '一句无心的话，让两个最好的朋友闹起了别扭。其他伙伴尝试撮合，却不断制造新的笑话。直到一个下雨的傍晚，两人在常去的小店相遇。一杯热可可和一段坦诚的对话，让他们发现自己都在等对方先开口。雨停了，友情也重新回到了熟悉的温度。';

  @override
  String get roleExampleStory6 =>
      '搬走前，大家列出一张共同生活的愿望清单。最后一项，是去看一次日出。为了赶上最早的车，他们经历了忘带钥匙、走错路和买不到早餐的小插曲。站在晨光里时，谁也没有说告别。他们只是约好，下一次相聚，再一起做一件小事。';

  @override
  String get officialRoles => '官方角色';

  @override
  String get roleDetails => '角色详情';

  @override
  String get roleArchive => '角色档案';

  @override
  String get rolePositioning => '人物定位';

  @override
  String get roleStyle => '性格与表达风格';

  @override
  String get roleAudience => '面向受众';

  @override
  String get roleTags => '内容标签';

  @override
  String get roleBoundaries => '表达边界';

  @override
  String get roleAppearance => '人物外形';

  @override
  String get roleFieldPending => '待补充';

  @override
  String get roleCertified => '已存证';

  @override
  String get roleUncertified => '未存证';

  @override
  String get roleProfileReady => '人设已就绪/可以继续丰富';

  @override
  String get roleProfilePending => '人设待完善';

  @override
  String get roleStoryTitle => '让角色更有自己的故事';

  @override
  String get roleStoryDescription => '和Agent聊聊性格、表达方式或新的创作方向。整理并确认后，用于下一次选题。';

  @override
  String get improveRole => '完善角色设定';

  @override
  String get confirmRoleChanges => '确认修改';

  @override
  String get savingRoleChanges => '保存中…';

  @override
  String get roleChangesSaved => '角色档案已保存';

  @override
  String get roleChangesSaveFailed => '角色档案保存失败，请稍后重试';

  @override
  String get roleFieldRequired => '请填写此项';

  @override
  String get roleEditCreationProfile => '修改此次角色档案';

  @override
  String get roleEditCreationArchive => '编辑本次创作档案';

  @override
  String get roleCreationEditTitle => '为本次创作调整角色设定';

  @override
  String get roleCreationEditDescription => '可修改角色描述、外形、性格、表达风格、受众和内容标签。';

  @override
  String get roleFieldInvalidFormat => '字段格式不正确';

  @override
  String get createWithRole => '围绕角色创作';

  @override
  String get deleteRoleTitle => '确认删除该角色？';

  @override
  String get deleteRoleDescription => '删除后，该角色将不会再出现在个人和社区角色库中，且无法恢复。';

  @override
  String get roleDeleteUnavailable => '当前角色不可删除';

  @override
  String improveRolePrompt(String title) {
    return '帮我完善角色“$title”的性格、表达方式和创作方向。';
  }

  @override
  String createRolePrompt(String title) {
    return '围绕角色“$title”创作，帮我推荐适合的选题。';
  }

  @override
  String get roleDescription => '角色介绍';

  @override
  String get noRoleDescription => '暂无角色介绍';

  @override
  String get myRoles => '我的角色';

  @override
  String get noOfficialRoles => '暂无官方角色';

  @override
  String get noMyRoles => '暂无我的角色';

  @override
  String get myRolesEmptyDescription => '创建角色作为人物资产丰富视频';

  @override
  String get createNewRole => '创建角色';

  @override
  String get createNewRolePrompt => '帮我创建一个新角色，先聊聊人物定位、性格和表达风格。';

  @override
  String get noMoreRoles => '已加载全部角色';

  @override
  String get retryLoadingRoles => '加载失败，点击重试';

  @override
  String get selectAssets => '批量选择';

  @override
  String get assetPreview => '图片预览';

  @override
  String get videoCoverPreview => '视频封面预览';

  @override
  String get videoPlay => '播放';

  @override
  String get videoPause => '暂停';

  @override
  String get videoMute => '静音';

  @override
  String get videoUnmute => '取消静音';

  @override
  String get videoSeek => '播放进度';

  @override
  String get videoLoadFailed => '视频播放失败';

  @override
  String get assetDownloadUnavailable => '当前资产没有可下载的源文件';

  @override
  String get deleteAssetsTitle => '确认删除资产？';

  @override
  String deleteAssetsDescription(int count) {
    return '将删除选中的 $count 个资产，此操作无法撤销。';
  }

  @override
  String selectedAssets(int count) {
    return '已选择 $count 项';
  }

  @override
  String get myIpAccounts => '我的IP账号';

  @override
  String get ipProjects => 'IP项目';

  @override
  String get teachingCenter => '教学中心';

  @override
  String get ipAccountsTitle => 'IP账号管理';

  @override
  String get deleteIpAccountTitle => '确认删除该IP账号？';

  @override
  String get deleteIpAccountDescription => '删除后，账号将被归档，不再显示在账号列表中。作品、会话和资料会保留。';

  @override
  String get loadingIpAccounts => '正在加载账号';

  @override
  String get ipAccountsAll => '全部';

  @override
  String get ipAccountsRecent => '最近常用';

  @override
  String get ipAccountsPaused => '停滞';

  @override
  String get ipAccountNormalStatus => 'Normal';

  @override
  String get ipAccountPausedStatus => 'Pause';

  @override
  String get noIpAccounts => '暂无IP账号';

  @override
  String get noRecentIpAccounts => '暂无最近常用账号';

  @override
  String get noPausedIpAccounts => '暂无停滞账号';

  @override
  String get ipAccountDetailsPending => '账号详情页待接入';

  @override
  String get ipAccountHomeTitle => '账号主页';

  @override
  String get ipAccountPreferences => '账号偏好';

  @override
  String get accountCreate => '创建账号';

  @override
  String get accountArchived => '已归档';

  @override
  String get accountActive => '正常';

  @override
  String get accountArchive => '归档账号';

  @override
  String get accountRestore => '恢复账号';

  @override
  String get accountArchiveConfirm => '归档后保留作品、会话和资料，可随时恢复。';

  @override
  String get accountMemory => '账号记忆';

  @override
  String get accountUserPrompt => '账号定位';

  @override
  String get accountPositioningHint => '填写账号的主题、风格和创作方向';

  @override
  String get accountConstraints => '创作约束';

  @override
  String get accountCustomOption => '自定义选项';

  @override
  String get accountInputInvalid => '内容为空、超出数量或长度限制';

  @override
  String get accountTitleInvalid => '请输入不超过15字的账号名称';

  @override
  String get accountRenameTitle => '重命名项目';

  @override
  String accountRenameConfirm(String title) {
    return '确认修改账号昵称为：\n$title';
  }

  @override
  String get accountArchives => '创作档案';

  @override
  String get accountArchiveSearch => '搜索标题或摘要';

  @override
  String get accountLoadMore => '加载更多';

  @override
  String get accountArchiveVersion => '版本';

  @override
  String get accountArchiveSummary => '摘要';

  @override
  String get accountArchiveBrief => '创作要求';

  @override
  String get accountArchiveTopic => '选题';

  @override
  String get accountArchiveScript => '脚本';

  @override
  String get accountArchiveStoryboard => '分镜视频提示词';

  @override
  String get accountArchiveCast => '角色快照';

  @override
  String get accountArchiveGeneration => '生成参数';

  @override
  String get accountOpenConversation => '查看会话';

  @override
  String get ipAccountPositioning => '账号定位';

  @override
  String get ipAccountFieldEmpty => '尚未填写';

  @override
  String get ipAccountEdit => '编辑';

  @override
  String get ipAccountSave => '保存';

  @override
  String get ipAccountSaved => '账号资料已保存';

  @override
  String get ipAccountLoadFailed => '账号资料加载失败，请重试';

  @override
  String get ipAccountResourcesFailed => '项目资产和角色加载失败';

  @override
  String get ipAccountAssets => '项目资产';

  @override
  String get ipAccountRoles => '项目角色';

  @override
  String get ipAccountNoAssets => '暂无作品';

  @override
  String get ipAccountNoRoles => '暂无项目角色';

  @override
  String get ipAccountCountSeparator => '：';

  @override
  String get ipAccountAssetsEmptyPrompt => '暂无作品，去和Agent聊聊做些什么';

  @override
  String get ipAccountRolesEmptyPrompt => '添加角色，建立自己的创作世界';

  @override
  String get ipAccountManageRoles => '管理项目角色';

  @override
  String get ipAccountRoleLimit => '最多添加20个角色';

  @override
  String get ipAccountPublish => '发布内容';

  @override
  String get ipAccountPublishEstimate => '约1分钟';

  @override
  String get ipAccountPublishReady => '账号已经准备好，可以从选题、想法、脚本或素材开始。';

  @override
  String get ipAccountStartContent => '开始一条新内容';

  @override
  String get ipAccountContinueConversation => '继续对话';

  @override
  String get ipAccountStartPrompt => '请根据这个账号的定位，帮我制作一条新内容。';

  @override
  String get ipAccountUnavailable => '账号已暂停';

  @override
  String get ipAccountsPending => 'IP账号功能待接入';

  @override
  String get newConversation => '新建对话';

  @override
  String get newSessionTitle => '新项目';

  @override
  String get changeAvatar => '更换头像';

  @override
  String get avatarSelectionFailed => '无法读取图片，请重新选择或检查相册权限';

  @override
  String get home => '首页';

  @override
  String get settings => '设置';

  @override
  String get chat => '聊天';

  @override
  String get sheetDemo => 'Sheet 示例';

  @override
  String get modalSheet => '普通底部 Sheet';

  @override
  String get draggableSheet => '可拖拽 Sheet';

  @override
  String get copyAction => '复制';

  @override
  String get uidCopied => 'UID 已复制';

  @override
  String get shareAction => '分享';

  @override
  String get imageShareFailed => '图片分享失败，请稍后重试';

  @override
  String get mediaShareFailed => '媒体分享失败，请稍后重试';

  @override
  String mediaPreviewPosition(int index, int count) {
    return '第 $index 项，共 $count 项';
  }

  @override
  String imagePreviewPosition(int index, int count) {
    return '第 $index 张，共 $count 张';
  }

  @override
  String get item => '项目';

  @override
  String get welcome => '你的新项目从这里开始。';

  @override
  String get theme => '主题';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get language => '语言';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get loginTitle => '欢迎登录 POPi';

  @override
  String get loginSubtitle => '登录后继续创作你的专属 IP';

  @override
  String get phoneNumber => '手机号';

  @override
  String get phoneNumberHint => '请输入手机号';

  @override
  String get passwordLogin => '密码登录';

  @override
  String get codeLogin => '验证码登录';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get invalidPassword => '请输入至少 6 位密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get graphicalCaptcha => '人机验证';

  @override
  String get captchaSliderHint => '向右拖动滑块完成拼图';

  @override
  String get captchaSliderMoving => '松开滑块完成验证';

  @override
  String get captchaVerifying => '正在验证…';

  @override
  String get captchaLoadFailed => '验证码加载失败，请点击刷新重试';

  @override
  String get captchaVerificationFailed => '验证失败，请重试';

  @override
  String get captchaTooManyErrors => '失败次数过多，请点击刷新重试';

  @override
  String get graphicalCaptchaHint => '请输入图中字符';

  @override
  String get refreshCaptcha => '刷新图形验证码';

  @override
  String get graphicalCaptchaRequired => '请先输入图形验证码';

  @override
  String get verificationCode => '验证码';

  @override
  String get verificationCodeHint => '请输入验证码';

  @override
  String get sendVerificationCode => '获取验证码';

  @override
  String get sendingVerificationCode => '发送中…';

  @override
  String get verificationCodeSent => '短信验证码已发送';

  @override
  String resendCountdown(int seconds) {
    return '$seconds 秒后重发';
  }

  @override
  String get phoneLogin => '手机号登录';

  @override
  String get loginOrRegister => '登录/注册';

  @override
  String get otherLoginMethods => '其他登录方式';

  @override
  String get wechatLogin => '微信登录';

  @override
  String get douyinLogin => '抖音登录';

  @override
  String get douyinLoginCanceled => '已取消抖音登录';

  @override
  String get douyinLoginUnavailable => '抖音登录不可用，请检查抖音是否已安装或应用配置是否完成';

  @override
  String get douyinLoginFailed => '抖音登录失败，请重试';

  @override
  String get douyinPhoneBindingRequired => '请绑定手机号以完成抖音登录';

  @override
  String get loginAgreement => '登录即代表同意《用户协议》和《隐私政策》';

  @override
  String get invalidPhoneNumber => '请输入正确的手机号';

  @override
  String get invalidVerificationCode => '请输入 6 位数字验证码';

  @override
  String get agreementRequired => '请先阅读并同意用户协议和隐私政策';

  @override
  String get loginSucceeded => '登录成功';

  @override
  String get networkRequestFailed => '网络请求失败，请稍后重试';

  @override
  String get wechatServicePending => '微信授权服务待接入';

  @override
  String get wechatLoginCanceled => '已取消微信登录';

  @override
  String get wechatLoginUnavailable => '微信登录不可用，请检查微信是否已安装或应用配置是否完成';

  @override
  String get wechatLoginFailed => '微信登录失败，请重试';

  @override
  String get wechatPhoneBindingRequired => '请先绑定手机号以完成微信登录';

  @override
  String get bindPhone => '绑定手机号';

  @override
  String get back => '返回';

  @override
  String get backToPreviousPage => '返回上一页';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get openNavigation => '打开导航';

  @override
  String get activities => '活动';

  @override
  String get activityCenter => '活动中心';

  @override
  String get activityEmpty => '暂无活动';

  @override
  String get activityUntitled => '活动';

  @override
  String get activityNoDescription => '暂无活动详情';

  @override
  String get activityLoadFailed => '活动加载失败，请重试';

  @override
  String get activityUnavailable => '活动已结束或暂未开放';

  @override
  String get activityOfficialCode => '官方兑换码';

  @override
  String get activityCodePlaceholder => '输入兑换码';

  @override
  String get activityOrderNumber => '订单编号';

  @override
  String get activityOrderPlaceholder => '请粘贴抖音订单编号';

  @override
  String activityMemberRestriction(String levels) {
    return '当前活动仅限$levels参加';
  }

  @override
  String activityMemberLevel(int level) {
    return '会员等级$level';
  }

  @override
  String get activityExchangeSuccess => '兑换成功';

  @override
  String get activityExchangeFailed => '兑换失败，请稍后重试';

  @override
  String get activityRefreshFailed => '兑换成功，会员信息暂未刷新，请稍后重新查看';

  @override
  String get activityQrTitle => '活动二维码';

  @override
  String get activityFinalConfirmation => '最终确认';

  @override
  String get activityRefundNotice =>
      '会员权益一经领取，即视为课程已核销使用，您将无法再向POPi申请退款。为确保您充分了解此规则，请在输入框中输入以下内容：';

  @override
  String get activityConfirmationPhrase => '我已知晓领取后不可退款';

  @override
  String get selectAction => '选择';

  @override
  String get conversationPending => '对话功能待接入';

  @override
  String get maximumImageCount => '最多上传5张图片';

  @override
  String get imageTooLarge => '单张图片不能超过6MB';

  @override
  String get imageReadFailed => '无法读取图片，请稍后重试';

  @override
  String imageUploadProgress(int percent) {
    return '上传中 $percent%';
  }

  @override
  String get imageUploadProcessing => '处理中';

  @override
  String get imageUploadFailed => '上传失败';

  @override
  String get imageUploadComplete => '上传完成';

  @override
  String get gallery => '相册';

  @override
  String get file => '文件';

  @override
  String get homeGreetingTitle => '嗨，我是POPi~\n';

  @override
  String get homeWelcomeGuest => '嗨，我是POPi～';

  @override
  String homeWelcomeUser(String name) {
    return '嗨，$name～';
  }

  @override
  String get homeWelcomeBody => '开始今天的创作吧';

  @override
  String get homeStartIp => '做一个新IP账号';

  @override
  String get homeStartRole => '从创建角色开始';

  @override
  String get homeStartContent => '从选题/内容/脚本开始';

  @override
  String homeBannerPage(int page, int total) {
    return '创作灵感，第$page张，共$total张';
  }

  @override
  String get homeGreetingBody => '我来帮你一起\n把一个账号做起来！';

  @override
  String get ipGuideIntroduction => '开始引导';

  @override
  String get ipGuideIntroBefore => '简单';

  @override
  String get ipGuideIntroFiveSteps => '5步';

  @override
  String get ipDraftTitle => '继续草稿，还是新建IP？';

  @override
  String get ipDraftDetected => '系统识别到一份新建定位草稿。';

  @override
  String get ipDraftDescription => '继续会恢复原步骤。重新创建会放弃这份定位草稿；已有IP项目的作品和素材会保留。';

  @override
  String get ipDraftRestart => '重新创建';

  @override
  String get ipDraftResume => '继续草稿';

  @override
  String get ipDraftSaveFailed => '草稿保存失败，请重试';

  @override
  String get ipNextAudience => '下一步：目标受众';

  @override
  String get ipAudienceQuestion => '你账号的目标受众是？';

  @override
  String get ipSelectAudience => '请选择目标受众或填写自己的受众';

  @override
  String get ipSelectNickname => '请为账号取一个名字';

  @override
  String get ipReselect => '重新选择';

  @override
  String get ipCreating => '正在创建…';

  @override
  String get ipCreateFailed => '创建未完成，草稿已保留，请重试';

  @override
  String get ipCreateSuccess => '创建成功！';

  @override
  String get ipCreateSuccessDescription => '从现在开始，每一次发布的内容都会积累在这里';

  @override
  String get ipCreateFirstRole => '创建第一个角色';

  @override
  String get ipCreateFirstContent => '制作第一条内容';

  @override
  String get ipOpenProject => '前往账号项目';

  @override
  String get ipFirstRolePrompt => '请根据这个账号的定位，帮我创建第一个角色。';

  @override
  String get ipFirstContentPrompt => '请根据这个账号的定位，帮我制作第一条内容。';

  @override
  String get ipAudienceStudents => '学生群体';

  @override
  String get ipAudienceWorkers => '职场人群';

  @override
  String get ipAudienceFamilies => '亲子家庭';

  @override
  String get ipAudienceAnimeFans => '漫剧迷';

  @override
  String get ipAudiencePetLovers => '萌宠爱好者';

  @override
  String get ipAudienceSeniors => '老年群体';

  @override
  String get ipAudienceStudentsDescription => '校园日常、学习成长，贴近年轻人的兴趣爱好与生活';

  @override
  String get ipAudienceWorkersDescription => '工作日常、职场进阶，关注打工人的心理压力与成长';

  @override
  String get ipAudienceFamiliesDescription => '育儿经验、亲子互动，关注家庭生活与孩子的陪伴话题';

  @override
  String get ipAudienceAnimeFansDescription => '动漫角色、二次元、幻想故事，热爱脑洞与创意表达';

  @override
  String get ipAudiencePetLoversDescription => '萌宠日常、养宠趣事，喜欢可爱又治愈的形象与内容';

  @override
  String get ipAudienceSeniorsDescription => '健康生活、兴趣休闲，关注退休后的品质与乐趣';

  @override
  String get ipPresentationPets => '拟人萌宠';

  @override
  String get ipPresentationClay => '粘土动画';

  @override
  String get ipPresentationInk => '国风水墨';

  @override
  String get ipVisualStyle => '视觉风格';

  @override
  String get ipGuideIntroAfter => '\n帮你创建IP账号';

  @override
  String get ipGuideStart => '开始创建';

  @override
  String ipGuideStep(int step) {
    return '第$step步';
  }

  @override
  String get ipDirectionQuestion => '你想长期分享什么？';

  @override
  String get ipFeelingQuestion => '你想让观众看完有什么感受？';

  @override
  String get ipPresentationQuestion => '你的账号，想以什么样子呈现？';

  @override
  String get ipReviewQuestion => '一份独属你的方案待你确认~';

  @override
  String get ipNextFeelings => '下一步：观看感受';

  @override
  String get ipNextPresentation => '下一步：呈现形态';

  @override
  String get ipNextReview => '下一步：确认方案';

  @override
  String get ipConfirmCreate => '确认创建';

  @override
  String get ipReview => '确认方案';

  @override
  String get ipContentDirection => '内容方向';

  @override
  String get ipAudienceFeeling => '观众感受';

  @override
  String get ipPresentation => '表现形式';

  @override
  String get ipContentFormat => '内容形式';

  @override
  String get ipTargetAudience => '目标受众';

  @override
  String get ipTargetAudienceValue => '愿意与你分享这种感受的人';

  @override
  String get ipCustomHint => '我要自己填写';

  @override
  String ipPrimarySelection(String label) {
    return '主方向：$label';
  }

  @override
  String ipSecondarySelection(String label) {
    return '辅助：$label';
  }

  @override
  String get ipMaximumSelections => '最多选择两个，先选主方向，再选辅助方向';

  @override
  String get ipSelectDirection => '请选择内容方向或填写自己的方向';

  @override
  String get ipSelectFeeling => '请选择观众感受或填写自己的感受';

  @override
  String get ipSelectPresentation => '请选择一种呈现形态';

  @override
  String get ipNotSelected => '未选择';

  @override
  String get ipAccountAvatar => '我';

  @override
  String get ipNewAccount => '我的新账号';

  @override
  String get ipAccountProfile => 'IP账号档案';

  @override
  String get ipAccountNickname => '账号昵称：';

  @override
  String get ipNicknameHint => '给账号取个好听的名字';

  @override
  String get ipDirectionCampus => '校园';

  @override
  String get ipDirectionEmotion => '情感';

  @override
  String get ipDirectionGrowth => '成长';

  @override
  String get ipDirectionCareer => '职场';

  @override
  String get ipDirectionFamily => '家庭';

  @override
  String get ipDirectionHumor => '搞笑';

  @override
  String get ipDirectionMystery => '悬疑';

  @override
  String get ipDirectionPets => '萌宠';

  @override
  String get ipDirectionKnowledge => '知识';

  @override
  String get ipFeelingAuthentic => '真实';

  @override
  String get ipFeelingMoving => '泪目';

  @override
  String get ipFeelingHealing => '治愈';

  @override
  String get ipFeelingGripping => '上头';

  @override
  String get ipFeelingDestiny => '宿命感';

  @override
  String get ipFeelingSurprising => '反转';

  @override
  String get ipFeelingAuthenticDescription => '像生活一样自然，让人产生共鸣';

  @override
  String get ipFeelingMovingDescription => '触动心底的柔软，让人感动落泪';

  @override
  String get ipFeelingHealingDescription => '温暖又安心，陪你慢慢放松下来';

  @override
  String get ipFeelingGrippingDescription => '节奏紧凑，让人忍不住接着看';

  @override
  String get ipFeelingDestinyDescription => '相遇与错过，命中注定的牵绊';

  @override
  String get ipFeelingSurprisingDescription => '意料之外的结局，带来惊喜';

  @override
  String get ipPresentationAiReal => 'AI真人';

  @override
  String get ipPresentation2d => '2D动漫';

  @override
  String get ipPresentation3d => '3D动漫';

  @override
  String get ipPresentationLive => '真人实拍';

  @override
  String get ipFormatShortFilm => '剧情短片';

  @override
  String get ipFormatComicDrama => '漫剧';

  @override
  String get ipFormatInteractiveDrama => '互动剧';

  @override
  String get ipFormatTalkingHead => '口播';

  @override
  String ipGuideSessionPrompt(
    String name,
    String direction,
    String feelings,
    String presentation,
    String format,
    String audience,
  ) {
    return '请帮我创建一个新的IP账号。\n账号昵称：$name\n内容方向：$direction\n观众感受：$feelings\n呈现形态：$presentation\n内容形式：$format\n目标观众：$audience';
  }

  @override
  String get homePromptIntro => '先告诉我：';

  @override
  String get homePromptQuestion => '你现在最想做什么？';

  @override
  String get homePromptCreateIp => '做一个新IP';

  @override
  String get homePromptImproveAccount => '让我的老账号变好';

  @override
  String get homePromptHasReference => '我已经有参考账号';

  @override
  String get homePromptUnsure => '我还不知道做什么';

  @override
  String get composerPlaceholder => '跟POPi说点什么...';

  @override
  String get composerRunning => '正在运行中';

  @override
  String get sessionWelcomeTitle => '嗨，用户～';

  @override
  String get sessionWelcomeBody => '告诉我，你现在最想做什么？';

  @override
  String get composerExpandInput => '展开输入框';

  @override
  String selectedImageLabel(String name) {
    return '已选择图片：$name';
  }

  @override
  String get removeImage => '移除图片';

  @override
  String get addAttachment => '添加附件';

  @override
  String get attachmentTitle => '添加';

  @override
  String get attachmentFeaturePending => '功能待开发';

  @override
  String get attachmentCamera => '拍摄';

  @override
  String get attachmentConfirm => '确认上传';

  @override
  String get attachmentLegalNotice => '温馨提示：您上传必须同意遵守用户协议和隐私政策，请确保上传的素材已获得合法权益';

  @override
  String get galleryManageAccess => '管理可访问照片';

  @override
  String get galleryOpenSettings => '相册权限设置';

  @override
  String get galleryAccessDenied => '未开启相册访问权限';

  @override
  String get galleryRestricted => '此设备限制了相册访问';

  @override
  String get galleryEmpty => '暂无可访问的照片';

  @override
  String get galleryLoadFailed => '照片加载失败，请重试';

  @override
  String get voiceInput => '语音输入';

  @override
  String get voiceInputStarting => '正在准备语音输入…';

  @override
  String get voiceInputListening => '正在聆听，点击麦克风结束';

  @override
  String get voiceInputFinishing => '正在识别…';

  @override
  String get voiceInputStop => '结束语音输入';

  @override
  String get voiceInputCancel => '取消语音输入';

  @override
  String get voiceInputPermissionDenied => '请在系统或浏览器设置中允许麦克风和语音识别权限';

  @override
  String get voiceInputUnavailable => '当前设备或浏览器暂不支持语音输入';

  @override
  String get voiceInputNoSpeech => '未识别到语音，请再试一次';

  @override
  String get voiceInputNetworkError => '语音识别连接失败，请检查网络后再试';

  @override
  String get voiceInputAudioError => '无法使用麦克风，请检查设备或是否被占用';

  @override
  String get voiceInputFailed => '语音识别失败，请再试一次';

  @override
  String get sendMessage => '发送消息';

  @override
  String get searchConversations => '搜索对话';

  @override
  String get newIpProject => '新建IP项目';

  @override
  String get drawerSessions => '对话';

  @override
  String get drawerNewConversation => '新建项目对话';

  @override
  String get drawerViewAll => '查看全部';

  @override
  String sessionItemOptions(String name) {
    return '会话“$name”的操作';
  }

  @override
  String projectCount(int count) {
    return '项目($count)';
  }

  @override
  String get projectOptions => '项目选项';

  @override
  String get expandAllProjects => '展开全部项目';

  @override
  String get collapseAllProjects => '收起全部项目';

  @override
  String get loginToViewProjects => '登录后查看项目';

  @override
  String get noProjects => '暂无项目';

  @override
  String get projectsTitle => '项目';

  @override
  String get loadingProjects => '正在加载项目';

  @override
  String get loadingProjectSessions => '正在加载会话';

  @override
  String get loadingRoles => '正在加载角色';

  @override
  String get loadingAssets => '正在加载资产';

  @override
  String get projectsLoadFailed => '项目加载失败';

  @override
  String get projectSessionsLoadFailed => '会话加载失败';

  @override
  String projectItemOptions(String name) {
    return '$name的选项';
  }

  @override
  String get renameProjectItem => '重命名';

  @override
  String get projectItemName => '名称';

  @override
  String get pinSession => '置顶会话';

  @override
  String get unpinSession => '取消置顶';

  @override
  String deleteProjectConfirm(String name) {
    return '删除「$name」及其全部会话？';
  }

  @override
  String deleteSessionConfirm(String name) {
    return '删除会话「$name」？';
  }

  @override
  String get projectItemRenamed => '重命名成功';

  @override
  String get projectItemDeleted => '删除成功';

  @override
  String get popiConversations => 'POPi对话';

  @override
  String get roles => '角色';

  @override
  String get assets => '资产';

  @override
  String get inspirationLibrary => '灵感库';

  @override
  String get inspirationPending => '灵感库功能待接入';

  @override
  String get tasks => '任务';

  @override
  String get notifications => '通知';

  @override
  String get notificationSystem => '系统通知';

  @override
  String get notificationPersonal => '个人通知';

  @override
  String get notificationNew => 'NEW';

  @override
  String get notificationUnread => '未读';

  @override
  String get notificationUntitled => '通知';

  @override
  String get notificationLearnMore => '了解详情';

  @override
  String get notificationDetail => '通知详情';

  @override
  String get notificationEmpty => '暂无通知';

  @override
  String get notificationLoadFailed => '通知加载失败，请重试';

  @override
  String get notificationLoadMore => '加载更多';

  @override
  String get notificationLoadMoreFailed => '加载更多通知失败，点击重试';

  @override
  String get notificationReadFailed => '标记已读失败，请重新打开通知重试';

  @override
  String get notificationLoginRequired => '登录后即可查看通知';

  @override
  String get notificationImageFailed => '图片加载失败';

  @override
  String get notificationViewImage => '查看通知图片';

  @override
  String notificationDaysAgo(int days) {
    return '$days天前';
  }

  @override
  String get profileSettings => '个人设置';

  @override
  String get taskLifeStoryVlog => '生活剧情Vlog';

  @override
  String get taskDouyinAiDrama => '抖音AI漫剧博主';

  @override
  String get taskCharacterIntroduction => '角色介绍撰写';

  @override
  String get taskCartoonIpCharacter => 'AI与插画师打造卡通IP角色功能';

  @override
  String get taskHumanRender => '人类渲染图生成需求';

  @override
  String get taskComedyVideoTopics => '搞笑视频相关话题';

  @override
  String get taskIpMonetization => 'IP商业化模式';

  @override
  String get taskBusinessPpt => '简约商务PPT模板';

  @override
  String get taskShanghaiBackground => '生成上海东方明珠繁华背景图';

  @override
  String get taskVideoCreatorRecommendations => '推荐短视频博主';

  @override
  String get taskWeiboTrends => '当前微博话题热度排行榜';

  @override
  String get taskComedyStoryVlog => '搞笑剧情Vlog';

  @override
  String downloadedWorks(int count) {
    return '已下载$count个作品';
  }

  @override
  String get creationHistory => '创作历史';

  @override
  String get creationHistoryLoadFailed => '创作历史加载失败';

  @override
  String get searchCreationHistory => '搜索创作历史';

  @override
  String get noMatchingHistory => '未找到匹配的创作历史';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get assetLibrary => '资产库';

  @override
  String get roleLibrary => '角色库';

  @override
  String get filterAll => '全部';

  @override
  String get agentAccountMode => 'Agent账号模式';

  @override
  String get vlog => 'Vlog';

  @override
  String get shortDrama => '短剧';

  @override
  String get images => '图片';

  @override
  String get videos => '视频';

  @override
  String get aiHuman => 'AI真人';

  @override
  String get anime => '二次元';

  @override
  String get threeD => '3D';

  @override
  String get noRoles => '暂无角色';

  @override
  String get noRolesDescription => '创建角色为你的视频增添人物资产';

  @override
  String get noHistory => '暂无历史';

  @override
  String get noWorks => '暂无作品';

  @override
  String get noHistoryDescription => '开启Agent对话\n创建属于你的短视频账号';

  @override
  String get noWorksDescription => '你创造的图片、视频、音频在这里';

  @override
  String get goGenerate => '去生成';

  @override
  String get yesterday => '昨天';

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String get sampleAccountQuestion => '有没有你喜欢、想学习的账号有...';

  @override
  String pointsSpent(int points) {
    return '本次消耗$points积分';
  }

  @override
  String get continueTask => '继续任务';

  @override
  String get download => '下载';

  @override
  String get sessionArtifactExported => '文档已导出';

  @override
  String get sessionArtifactExportFailed => '文档导出失败，请稍后重试';

  @override
  String get sessionArtifactSaved => '文件已保存';

  @override
  String get sessionArtifactSaveFailed => '文件保存失败，请稍后重试';

  @override
  String get imageSavedToPhotos => '图片已保存到相册';

  @override
  String get imageSaveFailed => '图片保存失败，请稍后重试';

  @override
  String get imageSaveAccessDenied => '无法保存图片，请在系统设置中允许添加照片';

  @override
  String get videoSavedToPhotos => '视频已保存到相册';

  @override
  String get videoSaveFailed => '视频保存失败，请稍后重试';

  @override
  String get videoSaveAccessDenied => '无法保存视频，请在系统设置中允许添加照片';

  @override
  String get delete => '删除';

  @override
  String get editProfile => '编辑资料';

  @override
  String get accountManagement => '账号管理';

  @override
  String get wechatId => '微信号';

  @override
  String get douyin => '抖音';

  @override
  String get socialBound => '已绑定';

  @override
  String get socialUnbound => '未绑定';

  @override
  String get socialBindingLoading => '处理中';

  @override
  String get socialBindingLoadFailed => '查询失败，重试';

  @override
  String get socialBindingSucceeded => '绑定成功';

  @override
  String get socialBindingCanceled => '已取消绑定';

  @override
  String get socialBindingUnavailable => '授权不可用，请检查对应应用是否已安装及授权配置';

  @override
  String get socialBindingFailed => '绑定失败，请重试';

  @override
  String get logout => '退出登录';

  @override
  String get logoutConfirmationTitle => '确认退出登录？';

  @override
  String get logoutDescription => '退出登录不会丢失任何数据\n你仍可以登录此账号';

  @override
  String get confirmLogout => '确认退出';

  @override
  String get logoutFailed => '退出登录失败，请稍后重试';

  @override
  String get cancelAccount => '注销账号';

  @override
  String get cancelAccountTitle => '确认注销账号？';

  @override
  String get cancelAccountDescription =>
      '注销后无法恢复或再次登录，所有设备将退出登录。\n原手机号及第三方账号无法自动重新注册。历史数据和作品仍会保留。';

  @override
  String get confirmCancelAccount => '确认注销';

  @override
  String get cancelAccountSucceeded => '注销成功';

  @override
  String get cancelAccountFailed => '注销失败，请稍后重试';

  @override
  String get regularUser => '普通用户';

  @override
  String memberLevel(String level) {
    return '$level会员';
  }

  @override
  String get upgradeMembership => '升级会员';

  @override
  String get goToLogin => '前往登录';

  @override
  String get membershipStarter => 'Starter 灵感初启';

  @override
  String get membershipPlus => 'Plus 创作进阶';

  @override
  String get membershipPro => 'Pro 旗舰能力';

  @override
  String get membershipMax => 'Max 作品研修';

  @override
  String get limitedDiscount => '限时6折';

  @override
  String get perMonth => '每月';

  @override
  String membershipPointsValue(String value) {
    return '每100积分≈￥$value元';
  }

  @override
  String get pointsPerMonth => '积分/月';

  @override
  String membershipPointsBreakdown(int packagePoints, int giftPoints) {
    return '包含：$packagePoints/套餐积分+$giftPoints/赠送积分';
  }

  @override
  String get membershipCoreBenefits => '会员核心权益';

  @override
  String get benefitVoiceClone => '声音克隆功能开启';

  @override
  String benefitConcurrentTasks(int count) {
    return '同时排队任务 ×$count';
  }

  @override
  String get benefitCharacters => '免费+部分会员角色';

  @override
  String get benefitWatermark => '无水印下载';

  @override
  String get benefitVip => '专属VIP通道';

  @override
  String get benefitStoragePrefix => '会员存储空间限制 ';

  @override
  String get openMembership => '立即开通';

  @override
  String get membershipComingSoon => '会员开通功能即将上线';

  @override
  String get paymentTitle => '确认支付';

  @override
  String get paymentChooseMethod => '支付方式';

  @override
  String get paymentWechat => '微信支付';

  @override
  String get paymentAlipay => '支付宝';

  @override
  String get paymentConfirm => '确认支付';

  @override
  String get paymentAmount => '支付金额';

  @override
  String get paymentPerYear => '每年';

  @override
  String get paymentPoints => '积分';

  @override
  String paymentGrantPoints(int points) {
    return '本次到账 $points 积分';
  }

  @override
  String get paymentCatalogPrice => '套餐价格，实际支付金额以订单为准';

  @override
  String get paymentCheckAgain => '再次查询';

  @override
  String get paymentProcessing => '支付处理中，到账后将更新权益';

  @override
  String get paymentCanceledPending => '已取消支付，订单状态待确认';

  @override
  String get paymentUnknown => '支付结果暂不可用，请先核对账单，避免重复付款';

  @override
  String get paymentNotCompleted => '订单未完成或已退款，未确认权益到账';

  @override
  String get paymentUnavailable => '支付服务暂不可用，请稍后重试';

  @override
  String get paymentAppNotInstalled => '未安装或暂不可用';

  @override
  String get paymentRetry => '重试';

  @override
  String get paymentDone => '完成';

  @override
  String get paymentOrderNumber => '订单号';

  @override
  String get paymentCopyOrder => '复制订单号';

  @override
  String get paymentOrderCopied => '订单号已复制';

  @override
  String get paymentPendingOrders => '其他待确认订单';

  @override
  String get paymentNewPurchase => '重新购买';

  @override
  String get paymentNewPurchaseWarning =>
      '原订单可能仍在支付中。请先核对微信或支付宝账单，重新购买会创建新的订单，可能导致重复付款。';

  @override
  String get purchaseProcessing => '正在连接 App Store…';

  @override
  String get purchaseSuccess => '购买成功，权益已更新';

  @override
  String get purchaseCanceled => '已取消购买';

  @override
  String get purchaseFailed => '购买未完成，请稍后重试';

  @override
  String get storeUnavailable => '当前无法连接 App Store';

  @override
  String get storeProductUnavailable => 'App Store 中未找到该商品，请检查商品配置';

  @override
  String get appleProductIdMissing => '该商品尚未配置 Apple Product ID';

  @override
  String get membershipCurrentPlan => '当前计划';

  @override
  String get membershipBuyNow => '立即购买';

  @override
  String membershipAlreadyMember(String level) {
    return '你已是$level';
  }

  @override
  String get membershipPlansEmpty => '暂无可用会员方案';

  @override
  String get membershipPlansLoadFailed => '会员方案加载失败';

  @override
  String get rechargeAndPoints => '充值 | 积分详情';

  @override
  String get rechargeAction => '充值';

  @override
  String get pointsDetailsTitle => '积分详情';

  @override
  String get rechargePointsPackage => '充值积分包';

  @override
  String get rechargedPoints => '充值积分';

  @override
  String get giftPoints => '赠送积分';

  @override
  String get pointsPackage => '积分包';

  @override
  String get pointPackagesEmpty => '暂无可用积分包';

  @override
  String get pointPackagesLoadFailed => '积分包加载失败';

  @override
  String get pointsUsageDescription =>
      '此信用额度/计划可在POPi移动端、POPi.Art跟POPi.TV上使用并且实时互通';

  @override
  String get dailyFreePoints => '每日免费积分';

  @override
  String get seedanceTrial => 'Seedance2.0体验版';

  @override
  String get samplePointsDate => '2026-09-02 09：46';

  @override
  String get pointsHistoryNotice => '可查看30天内的积分消耗明细，更新可能延时';

  @override
  String get pointsLogEmpty => '暂无积分明细';

  @override
  String get pointsLogLoadFailed => '积分明细加载失败';

  @override
  String get pointsLogUnknownSource => '积分变动';

  @override
  String get retry => '重试';

  @override
  String get pointsBalance => '余额';

  @override
  String get rechargeMembershipNotice =>
      '温馨提示：只有会员才可享受会员角色、图片视频去水印等功能。仅购买积分无法获得相应权益。购买的积分有效期为1年。';

  @override
  String get customerServiceContact => '客服联系方式:13100671900';

  @override
  String get rechargeAgreementPrefix => '充值即表示您同意遵守';

  @override
  String get userAgreement => '用户协议';

  @override
  String get conjunctionAnd => '和';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get webPageLoadFailed => '页面加载失败，请稍后重试';

  @override
  String get webPageLoading => '正在加载页面';

  @override
  String get webPageOpenInBrowser => '在浏览器中打开';

  @override
  String get webPageBrowserRequired => '请在浏览器中查看此页面';

  @override
  String get webPageRefresh => '刷新页面';

  @override
  String get nicknameRequiredLabel => '昵称*';

  @override
  String get nicknameHelp => '可以输入中文、英文、数字。最多15个字符。';

  @override
  String get nicknameRequired => '请输入昵称';

  @override
  String get profileUpdated => '资料已更新';

  @override
  String get profileUpdateFailed => '资料更新失败，请稍后重试';

  @override
  String get splashTagline => '“帮助人类更好的表达”';

  @override
  String get chatThinking => 'POPi正在思考你的内容';

  @override
  String get chatQueued => '排队中';

  @override
  String get chatWaitingExternal => '等待生成结果';

  @override
  String get chatCanceling => '正在停止';

  @override
  String get chatTopicSelected => '已选择的故事';

  @override
  String get chatTopicConfirmed => '已确认选题';

  @override
  String get chatCollapseStory => '收起故事';

  @override
  String get chatExpandStory => '展开故事';

  @override
  String get chatGenerationConfirmed => '已确认生成方案';

  @override
  String get chatGenerationCanceled => '已取消生成方案';

  @override
  String get chatReferenceImage => '参考图片';

  @override
  String get chatImageStyle => '画风';

  @override
  String get chatStyleLibrary => '风格库';

  @override
  String get chatStyleUnrestricted => '不限制风格';

  @override
  String get chatUnrestrictedStyle => '不限画风';

  @override
  String get chatGenerationRequirements => '补充要求';

  @override
  String get chatInvalidGeneration => '请检查模型、生成参数和参考素材';

  @override
  String get chatUnavailable => '暂不可用';

  @override
  String get chatGenerationTask => '生成任务';

  @override
  String get chatExpandTask => '展开任务';

  @override
  String get chatCollapseTask => '收起任务';

  @override
  String get chatGenerationWorking => '任务正在生成...';

  @override
  String get chatGenerationWorkingHint => '作品努力生成中...';

  @override
  String get chatGenerationTaskCompleted => '任务已完成';

  @override
  String get chatImageGenerationFailed => '图片生成失败';

  @override
  String get chatVideoGenerationFailed => '视频生成失败';

  @override
  String get chatTextGenerationTimeout => '文本生成超时，请重试';

  @override
  String get chatTextGenerationFailed => '文本生成失败，请重试';

  @override
  String get chatScriptGenerationFailed => '剧本生成失败，请重试';

  @override
  String get chatTopicGenerationFailed => '选题生成失败，请重试';

  @override
  String get chatResultCheckFailed => '视频完整性检查未通过，已保留生成结果';

  @override
  String get chatOutputValidationFailed => '生成结果校验未通过，请重试';

  @override
  String get chatStoryboardMissing => '缺少已保存的分镜内容，请确认分镜后再生成';

  @override
  String get chatVideoMissing => '未找到生成的视频结果，请重试';

  @override
  String get chatTaskInputChanged => '创作内容已变更，请重新确认生成方案';

  @override
  String get chatTaskConfirmationMismatch => '分镜版本与确认内容不一致，请重新确认分镜';

  @override
  String get chatVideoPromptInvalid => '生成提示词无效，请修改内容后重新确认';

  @override
  String get chatTaskResultUnavailable => '生成结果暂时无法读取，请稍后重试';

  @override
  String get chatTaskSubmissionFailed => '生成任务提交失败，请稍后重试';

  @override
  String get chatTaskServiceUnavailable => '生成服务暂时不可用，请稍后重试';

  @override
  String get chatRoleReferenceUnavailable => '角色参考图不可用，请更新角色图片并重新选择出场角色后再生成';

  @override
  String get chatProductionPlan => '生产方案';

  @override
  String get chatPlanCast => '出场角色';

  @override
  String get chatPlanStory => '选题故事';

  @override
  String get chatPlanHighlight => '核心看点';

  @override
  String get chatPlanConfiguration => '模型配置';

  @override
  String get chatPlanModel => '模型';

  @override
  String get chatPlanPoints => '预计消耗积分';

  @override
  String chatPlanCredits(String points) {
    return '$points 积分';
  }

  @override
  String get chatReviseContent => '修改内容';

  @override
  String chatRevisePrompt(String title) {
    return '请修改《$title》：';
  }

  @override
  String get chatBeforeChange => '修改前';

  @override
  String get chatAfterChange => '修改后';

  @override
  String get chatCompleteRole => '创建角色';

  @override
  String get chatConfirmProfileUpdate => '更新档案';

  @override
  String get chatRoleCreated => '角色草案已创建';

  @override
  String get chatRoleUpdated => '角色档案已更新';

  @override
  String get chatRolePublished => '角色档案已发布';

  @override
  String get chatViewRoleLibrary => '前往角色库查看';

  @override
  String get chatViewRoleProfile => '查看完整档案';

  @override
  String get chatCastRole => '出场角色';

  @override
  String get chatCastUnmatched => '未匹配';

  @override
  String chatCastMultiple(int count) {
    return '$count个角色';
  }

  @override
  String get chatConfirmCast => '确认出场角色';

  @override
  String get chatCastRoleUnavailable => '该角色暂不可用，请选择可读取且已保存档案的角色';

  @override
  String get chatRoleActive => '已发布';

  @override
  String get chatRoleDraft => '草稿';

  @override
  String get chatExpandProgress => '展开进度';

  @override
  String get chatCollapseProgress => '收起进度';

  @override
  String get chatThoughtProcess => '思考过程';

  @override
  String get chatStepPrepare => '准备';

  @override
  String get chatStepProcess => '处理需求';

  @override
  String get chatStepReply => '生成回复';

  @override
  String get chatStepSaveText => '保存内容';

  @override
  String get chatStepPreparePlan => '整理生成方案';

  @override
  String get chatStepAnalyze => '分析创作要求';

  @override
  String get chatStepReadRole => '读取角色档案';

  @override
  String get chatStepReadContext => '理解创作背景';

  @override
  String get chatStepTopics => '推荐选题';

  @override
  String get chatStepPrepareRole => '整理角色方案';

  @override
  String get chatStepSaveRole => '保存角色草案';

  @override
  String get chatStepPublishRole => '发布角色';

  @override
  String get chatStepVerifyResult => '核实执行结果';

  @override
  String get chatStepGenerateImage => '生成图片';

  @override
  String get chatStepGenerateVideo => '生成视频';

  @override
  String get chatStepGenerateAudio => '生成音频';

  @override
  String get chatStepSyncResult => '同步生成结果';

  @override
  String get chatPreparing => '正在准备…';

  @override
  String get chatProcessing => '正在处理你的需求';

  @override
  String get chatGeneratingReply => '正在生成回复…';

  @override
  String get chatSavingArtifact => '正在保存产物…';

  @override
  String get chatPlanningGeneration => '正在整理生成方案…';

  @override
  String get chatReadRole => '读取角色资料';

  @override
  String get chatReadContext => '读取创作上下文';

  @override
  String get chatTopics => '创作选题故事';

  @override
  String get chatPrepareRole => '准备角色创建';

  @override
  String get redemptionCenter => '邀请好友';

  @override
  String get redemptionPageTitle => '邀请好友';

  @override
  String get redemptionMyCodes => '我的邀请码';

  @override
  String get redemptionRegistrationReward => '注册奖励';

  @override
  String get redemptionInviteTitle => '邀请好友，赚积分';

  @override
  String get redemptionInviteDescription => '每邀请1位好友注册并登录\n即可获得200积分';

  @override
  String get redemptionRewardTitle => '好友邀请，领取好礼';

  @override
  String redemptionRewardDescription(int points) {
    return '输入好友分享的邀请码\n领取$points积分奖励';
  }

  @override
  String get redemptionPoints => '积分';

  @override
  String get redemptionFriendCode => '好友邀请码';

  @override
  String get redemptionFriendPlaceholder => '输入邀请码（每个用户仅一次）';

  @override
  String get redemptionClaimed => '已领取';

  @override
  String get redemptionPending => '待激活';

  @override
  String get redemptionUsed => '已被用户使用';

  @override
  String get redemptionRecords => '邀请记录';

  @override
  String get redemptionRegistered => '注册成功';

  @override
  String get redemptionCodesEmpty => '暂无邀请码';

  @override
  String get redemptionRecordsEmpty => '暂无邀请记录';

  @override
  String get redemptionFooter => '邀请奖励以活动规则为准，更新可能延时';

  @override
  String get redemptionLoadFailed => '加载失败，请重试';

  @override
  String get redemptionRewardClosed => '注册奖励活动暂未开放';

  @override
  String get redemptionClaimSuccess => '注册奖励领取成功';

  @override
  String get redemptionFailed => '兑换失败，请稍后重试';

  @override
  String get redemptionCopied => '邀请码已复制';

  @override
  String get redemptionLoadMore => '加载更多';

  @override
  String get redemptionLoginRequired => '登录后即可邀请好友';

  @override
  String get redemptionBindRequired => '绑定微信公众号后可查看邀请码';

  @override
  String get redemptionBindAction => '绑定微信公众号';

  @override
  String get redemptionBindDescription => '使用微信扫描二维码并完成绑定';

  @override
  String get redemptionQrExpired => '二维码已过期，请刷新';

  @override
  String get redemptionQrFailed => '二维码加载失败';

  @override
  String get redemptionBindingSuccess => '微信公众号绑定成功';

  @override
  String get redemptionBindingCheck => '检查绑定状态';

  @override
  String get redemptionBindingWaiting => '等待微信扫码绑定';

  @override
  String get teachingAll => '全部';

  @override
  String get teachingCatalog => '课程目录';

  @override
  String get teachingRequiredMember => '会员';

  @override
  String get teachingDocumentEmpty => '该课程暂无内容';

  @override
  String get teachingDocumentFailed => '课程内容加载失败，请重试';

  @override
  String get teachingReaderUnavailable => '当前平台暂不支持课程阅读';

  @override
  String get teachingCreatorTitle => '创作者中心';

  @override
  String get teachingCreatorDescription => '专为AI新手打造的\n一站式教学平台';

  @override
  String get teachingCommunityTitle => '加入社群';

  @override
  String get teachingCommunityDescription => '与创作者交流\n扫码加入POPi社群';

  @override
  String get teachingCommunityUnavailable => '社群二维码暂不可用';

  @override
  String get teachingMemberTitle => '会员特惠';

  @override
  String get teachingMemberDescription => '解锁更多优质课程\n探索创作的无限可能';

  @override
  String teachingMemberPrice(String price) {
    return '¥$price 起\n解锁更多优质课程';
  }

  @override
  String teachingInstructor(String name) {
    return '讲师：$name';
  }

  @override
  String get teachingFree => '免费';

  @override
  String get teachingUntitled => '未命名课程';

  @override
  String get teachingLoading => '正在加载课程';

  @override
  String get teachingEmpty => '暂无课程';

  @override
  String get teachingLoadFailed => '课程加载失败，请稍后重试';

  @override
  String get teachingLoadMoreFailed => '加载更多失败，点击重试';

  @override
  String get teachingCategoriesFailed => '分类加载失败，点击重试';

  @override
  String get sessionArtifactsTitle => '当前对话产物';

  @override
  String get sessionArtifactAll => '全部';

  @override
  String get sessionArtifactRoles => '角色';

  @override
  String get sessionArtifactScripts => '文本';

  @override
  String get sessionArtifactVideos => '视频';

  @override
  String get sessionArtifactAudioDetail => '音频详情';

  @override
  String get sessionArtifactImageDetail => '图片详情';

  @override
  String get sessionArtifactScriptDetail => '脚本详情';

  @override
  String get sessionArtifactVideoDetail => '视频详情';

  @override
  String get sessionArtifactsEmpty => '暂无产物';

  @override
  String get chatAskUser => '整理待确认信息';

  @override
  String get chatSaveRole => '保存角色档案';

  @override
  String get chatPublishRole => '准备角色发布';

  @override
  String get chatPreviewImage => '预览图片';

  @override
  String get chatCollapseProfile => '收起档案';

  @override
  String get chatConfirmGeneration => '确认生成';

  @override
  String get generationCreditNotice =>
      '温馨提示：点击「确认生成」后将扣除相应积分，已消耗积分不予退还。请在提交前仔细核对素材、提示词及生成参数';

  @override
  String get generationCreditNoticeNonRefundable => '已消耗积分不予退还';

  @override
  String get chatRoleName => '名称';

  @override
  String get chatReconnecting => '连接中断，正在重新连接…';

  @override
  String get chatRequestFailed => '请求失败，请稍后重试';

  @override
  String get chatInsufficientPoints => '积分不足，请充值后重试';

  @override
  String get chatRunFailed => '本次处理失败';

  @override
  String get chatStopped => '已停止';

  @override
  String get chatCompleted => '已完成';

  @override
  String get chatTextTopic => '选题故事';

  @override
  String get chatTextScript => '剧本';

  @override
  String get chatTextStoryboard => '分镜视频提示词';

  @override
  String get chatTextUnknownDuration => '未记录时长';

  @override
  String get chatProgressDetails => '执行进度';

  @override
  String get chatProgressPending => '待执行';

  @override
  String get chatProgressRunning => '执行中';

  @override
  String get chatProgressWaiting => '等待中';

  @override
  String get chatProgressFailed => '未完成';

  @override
  String get chatProgressCompleted => '已完成';

  @override
  String get chatProgressRunFailed => '执行失败';

  @override
  String get chatProgressStopped => '已停止回复';

  @override
  String get chatProgressPrepare => '准备创作上下文';

  @override
  String get chatProgressReply => '整理回复';

  @override
  String get chatProgressSaveText => '保存创作稿件';

  @override
  String get chatProgressPreparePlan => '准备生成方案';

  @override
  String get chatProgressUpdateRole => '更新角色资料';

  @override
  String get chatProgressProcessing => '正在处理…';

  @override
  String get chatProgressUnderstanding => '正在理解你的需求…';

  @override
  String get chatProgressSelectingSkill => '正在选择创作能力…';

  @override
  String get chatProgressReadingRules => '正在读取创作规则…';

  @override
  String get chatProgressComposing => '正在构思…';

  @override
  String get chatProgressPreparingGeneration => '正在准备生成任务…';

  @override
  String get chatProgressGeneratingArtifact => '正在生成正文…';

  @override
  String get chatProgressCompletingDelivery => '产物已生成，正在完成交付…';

  @override
  String get chatProgressWaitingInput => '等待你补充或确认…';

  @override
  String get chatProgressAnalyze => '正在分析创作要求';

  @override
  String get chatProgressExecuteTool => '执行业务操作';

  @override
  String get chatProgressLoadSkill => '加载创作方法';

  @override
  String get chatProgressSkillTopics => '加载选题创作方法';

  @override
  String get chatProgressSkillScript => '加载剧本创作方法';

  @override
  String get chatProgressSkillStoryboard => '加载分镜创作方法';

  @override
  String get chatProgressSkillThreeView => '加载三视图创作方法';

  @override
  String get chatProgressWriteScript => '编写剧本';

  @override
  String get chatProgressWriteStoryboard => '编写分镜与视频提示词';

  @override
  String get chatProgressReadTextSources => '读取采用的原稿和要求';

  @override
  String get chatProgressValidateText => '校验正文、时长与结构';

  @override
  String get chatProgressReadText => '读取创作稿件';

  @override
  String get chatProgressSearchRoles => '查找角色';

  @override
  String get chatProgressCreateRole => '创建角色';

  @override
  String get chatProgressCopyRole => '准备个人角色副本';

  @override
  String get chatProgressAdoptRoleImage => '保存采用的角色图片';

  @override
  String get chatProgressReadAccount => '读取账号资料';

  @override
  String get chatProgressSearchAccounts => '查找账号';

  @override
  String get chatProgressSelectAccount => '加载目标账号';

  @override
  String get chatProgressUpdateAccount => '更新账号偏好';

  @override
  String get chatProgressUpdateMemory => '整理账号记忆';

  @override
  String get chatProgressSearchCreations => '查找历史创作';

  @override
  String get chatProgressReadCreation => '读取历史创作';

  @override
  String get chatProgressReadTemplates => '读取画风模板';

  @override
  String get chatProgressReadReferences => '整理参考素材';

  @override
  String get chatProgressValidatePlan => '校验模型能力和生成参数';

  @override
  String get chatProgressEstimate => '预估生成积分';

  @override
  String get chatProgressVerifyResult => '正在核实执行结果';

  @override
  String get chatProgressCompilePrompt => '编写生图提示词';

  @override
  String get chatProgressValidatePrompt => '校验生图提示词';

  @override
  String get chatProgressSavePrompt => '保存生图提示词';

  @override
  String get chatProgressRetryPrompt => '提示词编译中断，等待重试';

  @override
  String get chatProgressSubmitGeneration => '提交生成任务';

  @override
  String get chatProgressQueuedGeneration => '等待生成';

  @override
  String get chatProgressGenerateImage => '正在生成图片';

  @override
  String get chatProgressGenerateVideo => '正在生成视频';

  @override
  String get chatProgressGenerateAudio => '正在生成音频';

  @override
  String get chatProgressSaveMedia => '保存生成结果';

  @override
  String get chatProgressSyncResult => '同步生成结果，正在重试';

  @override
  String get chatExpired => '已过期';

  @override
  String get chatAwaitingConfirmation => '等待确认';

  @override
  String get chatStop => '停止回复';

  @override
  String get chatSending => '正在发送';

  @override
  String get chatPlayVideo => '播放视频';

  @override
  String get chatPlayAudio => '播放音频';

  @override
  String get chatCustomAnswer => '补充你的想法';

  @override
  String get chatMediaPrompt => '请参考这些图片';

  @override
  String get chatHistoryLoadFailed => '会话记录加载失败';

  @override
  String chatEstimatedPoints(String points) {
    return '预计消耗 $points 积分';
  }

  @override
  String get demoConversations => '会话';

  @override
  String get demoAssets => '资产';

  @override
  String get demoSearchHistory => '搜索对话历史';

  @override
  String get demoSearchAssets => '搜索资产名称';

  @override
  String get demoProject => '项目';

  @override
  String get demoConversation => '对话';

  @override
  String get demoWorkflow => '工作流';

  @override
  String get demoNew => '新建会话';

  @override
  String get demoSettings => '会话设置';

  @override
  String get demoInfo => '信息';

  @override
  String get demoCapabilities => '能力';

  @override
  String get demoOutputs => '产物';

  @override
  String get demoLinkedRoles => '关联角色';

  @override
  String get demoAddMembers => '添加成员';

  @override
  String get demoMemberProfile => '机器人档案';

  @override
  String get demoRoleProfile => '角色档案';

  @override
  String get demoPopi => 'POPi';

  @override
  String get demoDesigner => '角色设计师';

  @override
  String get demoWriter => '特级编导';

  @override
  String get demoDirector => '金牌导演';

  @override
  String get demoSound => '声音达人';

  @override
  String get demoPopiDescription => '图文视频皆可的多元创作助手';

  @override
  String get demoDesignerDescription => '生成 IP 形象、创意角色与场景图片';

  @override
  String get demoWriterDescription => '编写剧情脚本，把想法整理成方案';

  @override
  String get demoDirectorDescription => '制作动态影像、可发布的媒体成片';

  @override
  String get demoSoundDescription => '生成配音、轻音乐、歌曲与音效';

  @override
  String get demoRename => '重命名会话';

  @override
  String get demoName => '名称';

  @override
  String get demoPreferences => '账号偏好';

  @override
  String get demoCreativeMemory => '创作偏好';

  @override
  String get demoEditCreativeMemory => '编辑创作偏好';

  @override
  String get demoCreativeMemoryEmpty => 'AI 会根据对话整理画面风格、具体模型偏好与比例，也可以手动填写。';

  @override
  String get demoCreativeMemoryScope => '仅用于当前会话，手动修改后 AI 不会自动覆盖。';

  @override
  String get demoCreativeMemoryEditorHint =>
      '这段内容会作为当前会话的创作记忆。请写明画面风格、图片/视频的具体模型偏好和比例。';

  @override
  String get demoCreativeMemoryAfterSave => '保存后，后续创作会自动使用这段记忆。';

  @override
  String get demoSaveToCurrentSession => '保存到当前会话';

  @override
  String get demoDirection => '内容方向';

  @override
  String get demoFeeling => '观众感受';

  @override
  String get demoFeelingValue => '主感受真实，次感受略带泪目';

  @override
  String get demoFormat => '表现形式';

  @override
  String get demoFormatValue => 'AI 真人视觉风格 × 剧情短片';

  @override
  String get demoAudience => '目标受众';

  @override
  String get demoAudienceValue => '学生群体 × 职场人群';

  @override
  String get demoPositioning => '账号定位';

  @override
  String get demoCharacterSkill => '角色设定';

  @override
  String get demoScriptSkill => '脚本与分镜';

  @override
  String get demoImageSkill => '图片生成';

  @override
  String get demoVideoSkill => '视频生成';

  @override
  String get demoAudioSkill => '音频生成';

  @override
  String get demoEnabledHere => '本会话已启用';

  @override
  String get demoWorkMode => '工作方式';

  @override
  String get demoOnDemand => '按需调用';

  @override
  String get demoOfficialRoles => '官方角色';

  @override
  String get demoMyRoles => '我的角色';

  @override
  String get demoCreateRole => '创建角色';

  @override
  String get demoJoin => '加入创作';

  @override
  String get demoNoRoles => '尚未关联角色';

  @override
  String get demoNoResults => '暂无匹配结果';

  @override
  String get demoEmptyAssets => '暂无资产';

  @override
  String get demoEmptyConversations => '暂无会话';

  @override
  String get demoAll => '全部';

  @override
  String get demoImages => '图片';

  @override
  String demoImageStackCount(int count) {
    return '$count 张图片';
  }

  @override
  String get demoVideos => '视频';

  @override
  String get demoScripts => '脚本';

  @override
  String get demoAudio => '音频';

  @override
  String get demoUpload => '上传素材';

  @override
  String get demoSampleLibrary => '素材库';

  @override
  String get demoImport => '导入';

  @override
  String get demoImported => '素材已加入资产库';

  @override
  String get demoAssetDetails => '资产详情';

  @override
  String get demoRenameAsset => '重命名资产';

  @override
  String get demoAudioDetails => '音频详情';

  @override
  String get demoAudioBackward => '后退15秒';

  @override
  String get demoAudioForward => '前进15秒';

  @override
  String get demoGenerated => '生成完成';

  @override
  String get demoComposer => '跟 POPi 说点什么…';

  @override
  String get demoGreeting => '嗨，用户～';

  @override
  String get demoGreetingDetail => '告诉我，你现在最想做什么？';

  @override
  String demoActivityTitle(String name, String activity) {
    return '$name · $activity';
  }

  @override
  String get demoActivityThinking => '正在思考你的内容';

  @override
  String get demoActivityModel => '正在调用模型';

  @override
  String get demoActivitySearching => '正在搜索资料';

  @override
  String get demoActivityReadingWeb => '正在阅读网页';

  @override
  String get demoActivityVision => '正在查看参考图片';

  @override
  String get demoThinking => 'POPi 正在思考…';

  @override
  String get demoVoice => '让爱丽丝在奶茶店遇见一位老朋友。';

  @override
  String get demoQuickImage => '批量生成五张场景图';

  @override
  String get demoQuickScript => '写一段重逢的脚本';

  @override
  String get demoQuickVideo => '生成一个周末出游视频';

  @override
  String get demoQuickAudio => '生成一段午后轻音乐';

  @override
  String get demoReply =>
      '可以把这个想法拍成一个温暖的短片。\\n\\n**三个选题**\\n1. 奶茶店里意外重逢的老朋友\\n2. 毕业前最后一次放学同行\\n3. 一封迟到很多年的信\\n\\n你想先展开哪一个？';

  @override
  String get demoImageReply => '场景图已生成，你看看这个造型喜欢吗？';

  @override
  String get demoScriptReply => '脚本与分镜已整理好。';

  @override
  String get demoAudioReply => '午后的轻音乐已生成。';

  @override
  String get demoVideoReply => '周末出游成片已生成。';

  @override
  String get demoWelcomeTitle => '嗨，逍遥的小柯子～';

  @override
  String get demoWelcomeCopy => '在创建会话之前\n请告诉我：\n你现在最想做什么？';

  @override
  String get demoStartIp => '做一个新IP账号';

  @override
  String get demoStartRole => '从DIY一个角色开始';

  @override
  String get demoStartIdea => '从一个想法或选题开始';

  @override
  String get demoStartChat => '我还没想好，先聊聊';

  @override
  String get demoReset => '恢复演示数据';

  @override
  String get demoResetDescription => '恢复初始会话和资产，清除本次演示中的修改？';

  @override
  String get demoResetDone => '已恢复初始数据';

  @override
  String get demoStorageError => '本地保存失败，请再次操作';

  @override
  String get demoDeleteDescription => '确认删除这条记录？';

  @override
  String get demoUpdated => '已保存';

  @override
  String get demoNow => '刚刚';

  @override
  String get demoPlayback => '播放';

  @override
  String get demoPause => '暂停';

  @override
  String get demoSeek => '播放位置';

  @override
  String get demoReplay => '重新播放';

  @override
  String get demoReference => '图片 / 参考';

  @override
  String get demoImageMeta => '图片 / 9:16';

  @override
  String demoOwnedImageMeta(int width, int height) {
    return '图片 / $width×$height';
  }

  @override
  String get demoScriptMeta => '脚本/MD';

  @override
  String get demoAudioMeta => '音频/00:24';

  @override
  String get demoVideoMeta => '视频 / 00:08';

  @override
  String get demoAttachments => '添加素材';

  @override
  String get demoRemoveAttachment => '移除素材';

  @override
  String get demoChoose => '选择成员';

  @override
  String get demoProfile => '个人资料';

  @override
  String get demoMembers => '成员';

  @override
  String get demoRoleBio => '热爱生活，喜欢把平凡的日常变成温暖的故事。';

  @override
  String get demoAddSkill => '添加能力';

  @override
  String get demoGenerating => '正在创作';

  @override
  String get demoNewRoleName => '角色名称';

  @override
  String get demoSend => '发送';

  @override
  String get demoSessionName => '会话名称';

  @override
  String demoRoleCount(int count) {
    return '$count人';
  }

  @override
  String demoSelectedCount(int count, int total) {
    return '已选 $count/$total';
  }

  @override
  String get demoSelectMembers => '选择成员';

  @override
  String get demoEditMember => '编辑成员';

  @override
  String get demoMyName => '我的名字';

  @override
  String get demoMyAppearance => '我的样子';

  @override
  String get demoRandomAppearance => '随机推荐';

  @override
  String demoAvatarNumber(int number) {
    return '头像 $number';
  }

  @override
  String get demoBackgroundColor => '背景颜色';

  @override
  String get demoProfileLink => '档案';

  @override
  String get demoEnabledItems => '启用项';

  @override
  String get demoCharacterDetail => '沿用 IP 人设与形象';

  @override
  String get demoScriptDetail => '把想法整理成完整方案';

  @override
  String get demoImageDetail => '创作角色图与场景图';

  @override
  String get demoVideoDetail => '制作可发布短视频平台的作品';

  @override
  String get demoAudioDetail => '生成配音、轻音乐、歌曲与音效';

  @override
  String get demoUploadLibrary => '上传到官方资产库';

  @override
  String get demoSelectFiles => '点击选择文件';

  @override
  String get demoFileTypes => '图片、视频、脚本、音频';

  @override
  String get demoUploadFiles => '上传到资产库';

  @override
  String get demoFileUploaded => '已上传';

  @override
  String get demoFileSelectionFailed => '无法选择文件，请再试一次';

  @override
  String get demoUploadFailed => '文件上传失败，请再试一次';

  @override
  String get demoUploadEmptyFile => '空文件无法上传';

  @override
  String get demoUploadTooLarge => '文件超过上传大小限制，请选择较小的文件';

  @override
  String get demoUploadUnsupported => '不支持该文件类型，请选择图片、MP4视频、文本脚本或音频';

  @override
  String get demoUploadInvalidFile => '文件无效或已发生变化，请重新选择';

  @override
  String get demoAssetLoadFailed => '文件加载失败，请稍后重新打开';

  @override
  String get demoInlineTextLoading => '正在加载文件';

  @override
  String get demoInlineTextCopied => '已复制全文';

  @override
  String get demoInlineTextExpand => '展开全文';

  @override
  String get demoInlineTextCollapse => '收起全文';

  @override
  String get demoInlineTextScrollHint => '滚动查看全文';

  @override
  String get demoInlineTextDownloadFormats => '下载文件';

  @override
  String demoInlineTextOpenFile(String name) {
    return '打开$name';
  }

  @override
  String demoFileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String demoFileSizeKb(String size) {
    return '$size KB';
  }

  @override
  String demoFileSizeBytes(int size) {
    return '$size 字节';
  }

  @override
  String demoSelectedFiles(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String get demoChooseBots => '选择Bot';

  @override
  String get demoChooseAssistant => '选择助理';

  @override
  String get demoCreateAssistant => '创建新的 Popi';

  @override
  String get demoAssistantName => 'Popi 名称';

  @override
  String get demoAssistantInstructions => '职责与个性';

  @override
  String get demoAssistantInstructionsHint => '描述 Popi 的职责、表达风格与协作偏好，可选';

  @override
  String get demoSingleAssistantNotice => '当前仅支持选择一名助理';

  @override
  String get demoDiyRoleTitle => '创建内容角色';

  @override
  String get demoUploadDiyRole => '上传 DIY 角色';

  @override
  String get demoSelectRoleImages => '选择角色参考图';

  @override
  String get demoDiyRoleNameHint => '角色名称';

  @override
  String get demoDiyRoleDescriptionHint => '人设与外观描述，可选';

  @override
  String get demoDiyRoleSave => '保存角色';

  @override
  String get demoDiyRoleLimit => '最多 5 张参考图';

  @override
  String get demoNewSessionRoleTitle => '先添加你的创作角色';

  @override
  String get demoNewSessionRoleHint => '关联已有角色，或上传自己的 DIY 角色参考图，让助理了解你的创作主角。';

  @override
  String get demoLinkContentRole => '关联角色';

  @override
  String get demoRoleContextReady => '已关联创作角色';

  @override
  String get demoStartCreating => '开始创作';

  @override
  String get demoCreateSessionAction => '创建';

  @override
  String get demoPinSession => '置顶';

  @override
  String get demoUnpinSession => '取消置顶';

  @override
  String get demoPopiAssistant => 'POPi助手';

  @override
  String get demoCurrentConversationOnly => '仅作用于当前会话';

  @override
  String get demoEditWorkMode => '工作方式';

  @override
  String get demoWorkModeAutomatic => '自动协作';

  @override
  String get demoWorkModeManual => '手动选择';

  @override
  String get demoWorkModeOnDemand => '按需调用';

  @override
  String get demoVoiceUnavailable => '语音输入尚未接入';

  @override
  String demoBotGroupTitle(int count) {
    return 'POPi等$count人';
  }

  @override
  String get demoGlobalCapabilities => '会话能力';

  @override
  String demoServerConfigRevision(int revision) {
    return '服务端配置 v$revision';
  }

  @override
  String get demoLocalConfig => '本地演示配置';

  @override
  String get demoVisionSkill => '视觉理解';

  @override
  String get demoVisionDetail => '理解图片内容并用于创作判断';

  @override
  String get demoCurrentTaskConfigNotice => '当前任务沿用受理时的配置；修改仅对后续任务生效';

  @override
  String get demoActiveMember => '指定执行成员';

  @override
  String get demoRolePending => '人设待配置';

  @override
  String get demoRoleConfigured => '人设已配置';

  @override
  String get demoRoleInstructions => '人设说明';

  @override
  String get demoRoleInstructionsHint => '描述角色外观、性格及创作约束，生成内容时作为参考';

  @override
  String get demoContextRolesHint => '用于图文、视频创作的角色与参考图，可在输入中用 @ 引用。';

  @override
  String get demoContextPreferencesHint => '作为后续创作的默认上下文，也可在本次提示词中另作说明。';

  @override
  String get demoReferenceImages => '角色参考图';

  @override
  String get demoAddReferenceImage => '添加参考图';

  @override
  String get demoReferenceImageUrls => '公开图片链接';

  @override
  String get demoReferenceImageUrlsHint => '每行一个公开图片链接，最多 5 个';

  @override
  String get demoReferenceImagesHint => '为创作提供外观参考。云端生成需要可访问的图片链接；本地图片不会自动公开。';

  @override
  String get demoDshCapabilitiesHint => '由 DSH 提供并默认启用，可用状态以实际接入为准。';

  @override
  String get demoDshTools => '工具';

  @override
  String get demoDshSkills => 'Skills';

  @override
  String get demoDshMcp => 'MCP';

  @override
  String get demoDshNotConnected => '尚未接入';

  @override
  String get demoDshNotGranted => '本会话未启用';

  @override
  String get demoDshUnavailable => '暂不可用';

  @override
  String get demoDshUnconfirmed => '状态待确认';

  @override
  String get demoLocalReferenceOnly => '本地参考图（云端暂不可用）';

  @override
  String get demoReferencePending => '参考图待读取';

  @override
  String get demoNotConfigured => '未设置';

  @override
  String get demoMentionRole => '引用角色';

  @override
  String get demoMentionRoleHint => '选择已关联的创作角色，将人设与参考图加入本次上下文。';

  @override
  String get demoTaskQueued => '任务已排队';

  @override
  String get demoTaskCreating => '正在制作';

  @override
  String get demoTaskSaving => '正在保存到资产库';

  @override
  String get demoTaskSaved => '已保存到资产库';

  @override
  String get demoViewOutputs => '查看产物';

  @override
  String get demoDismissTaskNotice => '关闭任务提示';

  @override
  String get demoTaskFailed => '任务失败';

  @override
  String get demoTaskUnknown => '任务状态待核实';

  @override
  String get demoTaskBrief => '任务简介';

  @override
  String get demoTaskDescriptionMissing => '该任务未保存文字简介';

  @override
  String get demoTaskExecutionMember => '执行成员';

  @override
  String get demoTaskModel => '模型';

  @override
  String get demoTaskConfiguration => '任务配置';

  @override
  String get demoTaskIdentifier => '任务 ID';

  @override
  String get demoTaskImage => '图片生成';

  @override
  String get demoTaskVideo => '视频生成';

  @override
  String get demoTaskTts => '语音合成';

  @override
  String get demoTaskMusic => '音乐生成';

  @override
  String get demoTaskVision => '视觉理解';

  @override
  String get demoTaskAudio => '音频生成';

  @override
  String get demoTaskText => '文本生成';

  @override
  String get demoTaskScript => '脚本生成';

  @override
  String get demoTaskMedia => '媒体任务';

  @override
  String demoTaskConfigRevision(int revision) {
    return '受理配置 v$revision';
  }

  @override
  String get harnessAccessTitle => '登录 POPi 测试版';

  @override
  String get harnessAccessSubtitle => '登录后连接测试环境，体验最新的应用功能';

  @override
  String get harnessAccessUsername => '账号';

  @override
  String get harnessAccessUsernameHint => '请输入测试账号';

  @override
  String get harnessAccessPassword => '密码';

  @override
  String get harnessAccessSignIn => '登录';

  @override
  String get harnessAccessSigningIn => '正在登录…';

  @override
  String get harnessAccessRequired => '请输入账号和密码';

  @override
  String get harnessAccessInvalidCredentials => '账号或密码不正确';

  @override
  String harnessAccessRateLimited(int seconds) {
    return '尝试次数过多，请在 $seconds 秒后重试';
  }

  @override
  String get harnessAccessRateLimitedUnknown => '尝试次数过多，请稍后重试';

  @override
  String get harnessAccessUnavailable => '暂时无法连接测试环境，请稍后重试';

  @override
  String get demoPinnedConversations => '置顶';

  @override
  String get demoRecentConversations => '最近会话';

  @override
  String get demoListNoMessages => '暂无消息';

  @override
  String get demoListYou => '你';

  @override
  String get demoListAttachment => '[附件]';

  @override
  String get demoListQuestion => '等待你的回答';

  @override
  String demoListMessagePreview(String sender, String message) {
    return '$sender：$message';
  }

  @override
  String demoListTime(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.Hm(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String demoListDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String demoListFullDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get demoMaterials => '素材';

  @override
  String composerNamedPlaceholder(String name) {
    return '跟$name说点什么...';
  }

  @override
  String get demoUploadFromDevice => '从设备上传';

  @override
  String get demoSelectFromLibrary => '从素材库选择';

  @override
  String get previewAttachment => '双击预览附件';

  @override
  String get demoAttachmentUnsupported => '当前助手暂不支持读取这类附件，请选择图片或文本脚本。';

  @override
  String get demoAttachmentNotFound => '附件已不存在，请移除后重新上传。';

  @override
  String get demoAttachmentTooLarge => '本次附件总大小过大，请减少附件或选择较小的文件。';

  @override
  String get demoAttachmentLimit => '附件数量过多或包含重复项，请调整后再发送。';

  @override
  String get demoAttachmentInvalid => '附件无法读取或已发生变化，请重新上传。';

  @override
  String get demoStyleFilmCapabilityTitle => '制作风格短片';

  @override
  String get demoStyleFilmCapabilityDescription => '启用后，可在对话输入区和＋菜单中选择短片风格。';

  @override
  String get demoStyleFilmSelect => '选择风格';

  @override
  String get demoStyleFilmChange => '更换风格';

  @override
  String get demoStyleFilmClear => '清除已选风格';

  @override
  String get demoStyleFilmMenu => '选择风格';

  @override
  String get demoStyleFilmSheetTitle => '短片风格';

  @override
  String get demoStyleFilmSearchHint => '搜索风格或用途';

  @override
  String get demoStyleFilmAllCategories => '全部分类';

  @override
  String get demoStyleFilmUnavailable => '暂不可制作';

  @override
  String get demoStyleFilmDuration => '时长';

  @override
  String get demoStyleFilmAspectRatio => '画幅';

  @override
  String get demoStyleFilmSoundtrack => '声音';

  @override
  String get demoStyleFilmSoundNone => '无声短片';

  @override
  String get demoStyleFilmSoundMusic => '原创配乐';

  @override
  String get demoStyleFilmStoryboardReview => '先看分镜，确认后制作';

  @override
  String get demoStyleFilmCreate => '使用这个风格';

  @override
  String get demoStyleFilmConfirmTitle => '确认创作简报';

  @override
  String demoStyleFilmConfirmDescription(
    String style,
    int seconds,
    String ratio,
  ) {
    return '使用「$style」制作 $seconds 秒、$ratio 的短片。先生成分镜，确认后再制作成片。';
  }

  @override
  String get demoStyleFilmCostPending => '制作会使用当前模型和服务器算力，具体模型用量以服务账单为准。';

  @override
  String get demoStyleFilmPreparingStoryboard => '正在准备分镜';

  @override
  String get demoStyleFilmAwaitingStoryboard => '分镜待你确认';

  @override
  String get demoStyleFilmApproveStoryboard => '确认分镜，开始制作';

  @override
  String get demoStyleFilmReviseStoryboard => '调整分镜';

  @override
  String get demoStyleFilmRevisionNotes => '希望怎样调整故事与画面？';

  @override
  String get demoStyleFilmRevisionNotice => '提交后将重新生成整套分镜，确认前不会制作成片。';

  @override
  String get demoStyleFilmSubmitRevision => '提交调整';

  @override
  String get demoStyleFilmCreating => '正在制作短片';

  @override
  String get demoStyleFilmCompleted => '短片已完成';

  @override
  String get demoStyleFilmFailed => '短片制作失败';

  @override
  String get demoStyleFilmViewOutput => '查看成片';

  @override
  String get demoStyleFilmNoReadyStyles => '当前没有可制作的风格，可先浏览风格目录。';

  @override
  String get demoStyleFilmLoadFailed => '风格目录读取失败，请稍后再打开。';

  @override
  String get demoStyleFilmReviewFailed => '分镜操作未提交，已保留你的选择和输入。';

  @override
  String get demoStyleFilmSaveFailed => '能力设置未保存，已保留你的修改。';

  @override
  String get demoStyleFilmRetry => '重新制作';

  @override
  String demoStyleFilmStyleCount(int count) {
    return '$count 种风格';
  }

  @override
  String demoStyleFilmPosterLabel(String name) {
    return '$name风格示例';
  }

  @override
  String get demoStyleFilmPreviewLabel => '分镜预览';

  @override
  String get demoStyleFilmNoStoryboard => '分镜尚未就绪，制作进展会保留在原会话中。';

  @override
  String get demoStyleFilmUpload => '从设备上传';

  @override
  String get demoStyleFilmLibrary => '从素材库选择';

  @override
  String get demoStyleFilmReferencesUnsupported => '当前风格短片仅支持文字主题，请先移除附件和内容角色。';

  @override
  String demoStyleFilmBotContext(String name) {
    return '适用于 Bot：$name';
  }

  @override
  String get demoStyleFilmLoadingCatalog => '正在加载风格目录';

  @override
  String demoStyleFilmReadyCount(int count) {
    return '可制作 $count 种';
  }

  @override
  String get demoStyleFilmBrowsePending => '可以浏览全部风格，完成验证后即可选择制作。';

  @override
  String get demoStyleFilmNoReadyFooter => '当前没有已验证可制作的风格';

  @override
  String get demoStyleFilmReasonUnsupportedStyle => '暂未适配';

  @override
  String get demoStyleFilmReasonUnverifiedStyle => '待验证';

  @override
  String get demoStyleFilmReasonRuntimeUnavailable => '暂时无法制作';

  @override
  String get demoStyleFilmReasonModelUnavailable => '当前模型未就绪';

  @override
  String get demoStyleFilmReasonUnknown => '暂不可制作';

  @override
  String get demoStyleFilmCapabilitiesHint =>
      '能力由 DSH 提供；Bot 专属创作技能按需启用，可用状态以实际连接为准。';

  @override
  String get demoPasteImage => '粘贴图片';

  @override
  String get demoPasteImageUnavailable => '剪贴板中没有可用图片';

  @override
  String get demoPasteImageFailed => '图片未粘贴，已保留当前输入和附件';

  @override
  String get demoPastingImages => '正在添加剪贴板图片';

  @override
  String get demoDocuments => '文档';

  @override
  String get demoDocumentParsing => '正在解析文档';

  @override
  String get demoDocumentReady => '文档已解析，可发送给助理读取';

  @override
  String demoDocumentPages(int count) {
    return '$count 页';
  }

  @override
  String demoDocumentSlides(int count) {
    return '$count 张幻灯片';
  }

  @override
  String get demoDocumentTruncated => '内容已按读取上限截断';

  @override
  String get demoDocumentOcrUsed => '已使用 OCR 识别';

  @override
  String get demoDocumentPageCountEstimated => '页数为估算值';

  @override
  String get demoDocumentTextEmpty => '文档中没有可读取的文字';

  @override
  String get demoDocumentOriginalAvailable => '原文件可下载';

  @override
  String get demoDocumentLimitHint =>
      '最多 10 个附件，共 50 MB；图片共 20 MB。文档单个 20 MB，PDF 最多 100 页，PPT 最多 100 张。';

  @override
  String get demoAttachmentParsing => '附件仍在解析，请稍候再发送';

  @override
  String demoSkillBotContext(String name) {
    return '适用于 Bot：$name';
  }

  @override
  String get demoSkillSaveFailed => 'Skill 设置未保存，已保留你的选择。';

  @override
  String get demoRolePreviewEdit => '编辑档案';

  @override
  String get demoRolePreviewNoReferences => '暂无角色参考图';

  @override
  String demoRolePreviewMissingReferences(int count) {
    return '$count 张参考图暂不可用';
  }

  @override
  String demoRolePreviewReferenceCount(int count) {
    return '$count 张参考图';
  }

  @override
  String get demoRolePreviewFullInstructions => '查看完整原始说明';

  @override
  String get demoRolePreviewCollapseInstructions => '收起完整原始说明';
}
