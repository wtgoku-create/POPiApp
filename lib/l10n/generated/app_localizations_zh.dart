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
  String get graphicalCaptcha => '图形验证码';

  @override
  String get graphicalCaptchaHint => '请输入图中字符';

  @override
  String get refreshCaptcha => '刷新图形验证码';

  @override
  String get graphicalCaptchaRequired => '请先输入图形验证码';

  @override
  String get verificationCode => '验证码';

  @override
  String get verificationCodeHint => '请输入 6 位验证码';

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
  String get otherLoginMethods => '其他登录方式';

  @override
  String get wechatLogin => '微信登录';

  @override
  String get loginAgreement => '我已阅读并同意《用户协议》和《隐私政策》';

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
  String get homeGreetingBody => '我来帮你一起\n把一个账号做起来！';

  @override
  String get homePromptIntro => '先告诉我：';

  @override
  String get homePromptQuestion => '你现在最想做什么？';

  @override
  String get homePromptCreateIp => '做一个新IP';

  @override
  String get homePromptImproveAccount => '让我的老帐号变好';

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
  String get voiceInput => '语音输入';

  @override
  String get sendMessage => '发送消息';

  @override
  String get searchConversations => '搜索对话';

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
  String get logoutDescription => '退出后需要重新登录才能继续使用';

  @override
  String get confirmLogout => '确认退出登录';

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
      '温馨提示：只有会员才可享受会员角色、图片视频去水印等功能。仅购买积分无法获得相应权益。购买的积分有效期为1年。如有任何疑问，请联系客服。';

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
  String get splashTagline => '让创意更有价值。';
}
