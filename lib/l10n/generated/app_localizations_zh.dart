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
  String get roleGuideTitle => '从角色出发';

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
  String get roleStoryboardContent => '分镜内容';

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
  String get ipAccountsTitle => 'IP账号管理';

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
  String get ipAccountStartPrompt => '请根据这个账号的定位，帮我制作一条新内容。';

  @override
  String get ipAccountUnavailable => '账号已暂停';

  @override
  String get ipAccountsPending => 'IP账号功能待接入';

  @override
  String get newConversation => '新建对话';

  @override
  String get newSessionTitle => '新会话';

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
  String get aiDisclaimer => 'AI生成结果可能有误，仅供参考';

  @override
  String get composerPlaceholder => '跟POPi说点什么...';

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
  String get sendMessage => '发送消息';

  @override
  String get searchConversations => '搜索对话';

  @override
  String get newIpProject => '新建IP项目';

  @override
  String get drawerSessions => '会话';

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
  String get regularUser => '普通用户';

  @override
  String memberLevel(String level) {
    return '会员 $level';
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
  String get restorePurchases => '恢复购买';

  @override
  String get appleRestoreIncomplete => '部分购买尚未恢复成功，请稍后重试';

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
  String get restorePurchasesRequested => '已从账户同步购买记录和会员权益';

  @override
  String get membershipCurrentPlan => '当前计划';

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
      '此信用额度/计划可在POPi移动端、POPi.air跟POPi.TV上使用并且实时互通';

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
  String get chatRoleCreated => '角色草案已创建';

  @override
  String get chatRoleUpdated => '角色草案已更新';

  @override
  String get chatRolePublished => '角色已发布';

  @override
  String get chatExpandProgress => '展开进度';

  @override
  String get chatCollapseProgress => '收起进度';

  @override
  String get chatPreparing => '正在准备';

  @override
  String get chatProcessing => '正在处理你的需求';

  @override
  String get chatGeneratingReply => '正在生成回复';

  @override
  String get chatSavingArtifact => '正在保存内容';

  @override
  String get chatPlanningGeneration => '正在整理生成方案';

  @override
  String get chatReadRole => '正在读取角色档案';

  @override
  String get chatReadContext => '正在理解创作背景';

  @override
  String get chatTopics => '正在推荐选题';

  @override
  String get chatPrepareRole => '正在整理角色方案';

  @override
  String get chatAskUser => '等待补充信息';

  @override
  String get chatSaveRole => '正在保存角色草案';

  @override
  String get chatPublishRole => '正在发布角色';

  @override
  String get chatPreviewImage => '预览图片';

  @override
  String get chatCollapseProfile => '收起档案';

  @override
  String get chatConfirmGeneration => '确认生成';

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
}
