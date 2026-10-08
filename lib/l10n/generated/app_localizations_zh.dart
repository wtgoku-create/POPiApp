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
  String get ipGuideIntroFourSteps => '4步';

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
  String get ipFeelingQuestion => '你想让观众有什么感受？';

  @override
  String get ipPresentationQuestion => '你的账号，想以什么样子出现？';

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
  String get ipPresentation => '呈现形态';

  @override
  String get ipContentFormat => '内容形式';

  @override
  String get ipTargetAudience => '目标观众';

  @override
  String get ipTargetAudienceValue => '愿意与你分享这种感受的人';

  @override
  String get ipCustomHint => '以上都不满意，我要自己填写';

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
}
