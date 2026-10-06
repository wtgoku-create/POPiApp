// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'POPi';

  @override
  String get officialRoles => 'Official roles';

  @override
  String get roleDetails => 'Role details';

  @override
  String get roleArchive => 'Role profile';

  @override
  String get rolePositioning => 'Character positioning';

  @override
  String get roleStyle => 'Personality and expression style';

  @override
  String get roleAudience => 'Target audience';

  @override
  String get roleTags => 'Content tags';

  @override
  String get roleBoundaries => 'Expression boundaries';

  @override
  String get roleAppearance => 'Appearance';

  @override
  String get roleFieldPending => 'To be completed';

  @override
  String get roleCertified => 'Certified';

  @override
  String get roleUncertified => 'Uncertified';

  @override
  String get roleProfileReady => 'Profile ready / Keep enriching it';

  @override
  String get roleProfilePending => 'Profile needs more details';

  @override
  String get roleStoryTitle => 'Give your character a richer story';

  @override
  String get roleStoryDescription =>
      'Talk with the Agent about personality, expression or a new creative direction. Confirm the details for your next topic.';

  @override
  String get improveRole => 'Enrich role profile';

  @override
  String get createWithRole => 'Create with this role';

  @override
  String get deleteRoleTitle => 'Delete this role?';

  @override
  String get deleteRoleDescription =>
      'This role will be removed from your personal and community libraries. This cannot be undone.';

  @override
  String get roleDeleteUnavailable => 'This role cannot be deleted';

  @override
  String improveRolePrompt(String title) {
    return 'Help enrich the personality, expression and creative direction of $title.';
  }

  @override
  String createRolePrompt(String title) {
    return 'Recommend creative topics featuring $title.';
  }

  @override
  String get roleDescription => 'About this role';

  @override
  String get noRoleDescription => 'No description yet';

  @override
  String get myRoles => 'My roles';

  @override
  String get noOfficialRoles => 'No official roles yet';

  @override
  String get noMyRoles => 'No roles of your own yet';

  @override
  String get myRolesEmptyDescription =>
      'Create characters to enrich your videos';

  @override
  String get createNewRole => 'Create a role';

  @override
  String get createNewRolePrompt =>
      'Help me create a new character. Let\'s start with positioning, personality and expression style.';

  @override
  String get noMoreRoles => 'All roles loaded';

  @override
  String get retryLoadingRoles => 'Could not load roles. Retry';

  @override
  String get selectAssets => 'Select assets';

  @override
  String get assetPreview => 'Image preview';

  @override
  String get videoCoverPreview => 'Video cover preview';

  @override
  String get assetDownloadUnavailable =>
      'No source file is available to download';

  @override
  String get deleteAssetsTitle => 'Delete assets?';

  @override
  String deleteAssetsDescription(int count) {
    return 'Delete $count selected assets? This cannot be undone.';
  }

  @override
  String selectedAssets(int count) {
    return '$count selected';
  }

  @override
  String get myIpAccounts => 'My IP accounts';

  @override
  String get ipAccountsPending => 'IP accounts are not available yet';

  @override
  String get newConversation => 'New conversation';

  @override
  String get changeAvatar => 'Change avatar';

  @override
  String get avatarSelectionFailed =>
      'Could not read the image. Try again or check photo permissions.';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get chat => 'Chat';

  @override
  String get sheetDemo => 'Sheet Demo';

  @override
  String get modalSheet => 'Modal Bottom Sheet';

  @override
  String get draggableSheet => 'Draggable Sheet';

  @override
  String get copyAction => 'Copy';

  @override
  String get uidCopied => 'UID copied';

  @override
  String get shareAction => 'Share';

  @override
  String get item => 'Item';

  @override
  String get welcome => 'Your new project starts here.';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get chinese => 'Chinese';

  @override
  String get english => 'English';

  @override
  String get loginTitle => 'Welcome to POPi';

  @override
  String get loginSubtitle => 'Sign in to continue creating your own IP';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneNumberHint => 'Enter your phone number';

  @override
  String get passwordLogin => 'Password sign-in';

  @override
  String get codeLogin => 'SMS sign-in';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get invalidPassword => 'Enter a password with at least 6 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get graphicalCaptcha => 'Security verification';

  @override
  String get captchaSliderHint => 'Drag the slider to complete the puzzle';

  @override
  String get captchaSliderMoving => 'Release to verify';

  @override
  String get captchaVerifying => 'Verifying…';

  @override
  String get captchaLoadFailed => 'Could not load captcha. Refresh to retry';

  @override
  String get captchaVerificationFailed => 'Verification failed. Try again';

  @override
  String get captchaTooManyErrors => 'Too many attempts. Refresh to retry';

  @override
  String get graphicalCaptchaHint => 'Enter the characters';

  @override
  String get refreshCaptcha => 'Refresh image verification';

  @override
  String get graphicalCaptchaRequired =>
      'Enter the image verification code first';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get verificationCodeHint => 'Enter the 6-digit code';

  @override
  String get sendVerificationCode => 'Send code';

  @override
  String get sendingVerificationCode => 'Sending…';

  @override
  String get verificationCodeSent => 'Verification code sent';

  @override
  String resendCountdown(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get phoneLogin => 'Continue with phone';

  @override
  String get loginOrRegister => 'Sign in / Register';

  @override
  String get otherLoginMethods => 'Other sign-in methods';

  @override
  String get wechatLogin => 'Continue with WeChat';

  @override
  String get douyinLogin => 'Douyin sign-in';

  @override
  String get douyinLoginCanceled => 'Douyin sign-in was canceled';

  @override
  String get douyinLoginUnavailable =>
      'Douyin sign-in is not available yet. Use your phone number or WeChat.';

  @override
  String get douyinLoginFailed => 'Douyin sign-in failed. Please try again.';

  @override
  String get douyinPhoneBindingRequired =>
      'Bind your phone number to complete Douyin sign-in.';

  @override
  String get loginAgreement =>
      'By signing in, you agree to the User Agreement and Privacy Policy. New phone numbers register automatically.';

  @override
  String get invalidPhoneNumber => 'Enter a valid phone number';

  @override
  String get invalidVerificationCode => 'Enter a valid 6-digit code';

  @override
  String get agreementRequired =>
      'Please agree to the User Agreement and Privacy Policy first';

  @override
  String get loginSucceeded => 'Signed in successfully';

  @override
  String get networkRequestFailed => 'Network request failed. Try again later';

  @override
  String get wechatServicePending =>
      'WeChat authorization is not connected yet';

  @override
  String get wechatLoginCanceled => 'WeChat sign-in was canceled';

  @override
  String get wechatLoginUnavailable =>
      'WeChat sign-in is unavailable. Check that WeChat is installed and the app is configured.';

  @override
  String get wechatLoginFailed => 'WeChat sign-in failed. Please try again.';

  @override
  String get wechatPhoneBindingRequired =>
      'Bind a phone number to finish WeChat sign-in';

  @override
  String get bindPhone => 'Bind phone number';

  @override
  String get back => 'Back';

  @override
  String get backToPreviousPage => 'Back to previous page';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get openNavigation => 'Open navigation';

  @override
  String get selectAction => 'Select';

  @override
  String get conversationPending => 'Conversations are not connected yet';

  @override
  String get maximumImageCount => 'You can upload up to 5 images';

  @override
  String get imageTooLarge => 'Each image must be no larger than 6 MB';

  @override
  String get imageReadFailed => 'Unable to read the image. Try again later';

  @override
  String get gallery => 'Photos';

  @override
  String get file => 'File';

  @override
  String get homeGreetingTitle => 'Hi, I\'m POPi~\n';

  @override
  String get homeGreetingBody => 'I\'ll help you\nbuild an account together!';

  @override
  String get homePromptIntro => 'First, tell me:';

  @override
  String get homePromptQuestion => 'What do you want to do most right now?';

  @override
  String get homePromptCreateIp => 'Create a new IP';

  @override
  String get homePromptImproveAccount => 'Improve my existing account';

  @override
  String get homePromptHasReference => 'I already have a reference account';

  @override
  String get homePromptUnsure => 'I\'m not sure what to create yet';

  @override
  String get aiDisclaimer =>
      'AI-generated results may be inaccurate and are for reference only';

  @override
  String get composerPlaceholder => 'Say something to POPi...';

  @override
  String selectedImageLabel(String name) {
    return 'Selected image: $name';
  }

  @override
  String get removeImage => 'Remove image';

  @override
  String get addAttachment => 'Add attachment';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get sendMessage => 'Send message';

  @override
  String get searchConversations => 'Search conversations';

  @override
  String get popiConversations => 'POPi conversations';

  @override
  String get roles => 'Roles';

  @override
  String get assets => 'Assets';

  @override
  String get inspirationLibrary => 'Inspiration';

  @override
  String get inspirationPending => 'Inspiration is not connected yet';

  @override
  String get tasks => 'Tasks';

  @override
  String get notifications => 'Notifications';

  @override
  String get profileSettings => 'Profile settings';

  @override
  String get taskLifeStoryVlog => 'Lifestyle story vlog';

  @override
  String get taskDouyinAiDrama => 'Douyin AI comic creator';

  @override
  String get taskCharacterIntroduction => 'Write a character introduction';

  @override
  String get taskCartoonIpCharacter =>
      'Create a cartoon IP character with AI and illustrators';

  @override
  String get taskHumanRender => 'Generate a human rendering';

  @override
  String get taskComedyVideoTopics => 'Comedy video topics';

  @override
  String get taskIpMonetization => 'IP monetization models';

  @override
  String get taskBusinessPpt => 'Minimal business presentation template';

  @override
  String get taskShanghaiBackground => 'Generate a bustling Shanghai skyline';

  @override
  String get taskVideoCreatorRecommendations =>
      'Recommend short-video creators';

  @override
  String get taskWeiboTrends => 'Current Weibo trending topics';

  @override
  String get taskComedyStoryVlog => 'Comedy story vlog';

  @override
  String downloadedWorks(int count) {
    return 'Downloaded $count works';
  }

  @override
  String get creationHistory => 'History';

  @override
  String get assetLibrary => 'Library';

  @override
  String get roleLibrary => 'Characters';

  @override
  String get filterAll => 'All';

  @override
  String get agentAccountMode => 'Agent account';

  @override
  String get vlog => 'Vlog';

  @override
  String get shortDrama => 'Short drama';

  @override
  String get images => 'Images';

  @override
  String get videos => 'Videos';

  @override
  String get aiHuman => 'AI human';

  @override
  String get anime => 'Anime';

  @override
  String get threeD => '3D';

  @override
  String get noRoles => 'No characters yet';

  @override
  String get noRolesDescription =>
      'Create characters to add reusable talent to your videos';

  @override
  String get noHistory => 'No history yet';

  @override
  String get noWorks => 'No works yet';

  @override
  String get noHistoryDescription =>
      'Start an Agent conversation\nto create your own short-video account';

  @override
  String get noWorksDescription =>
      'Your images, videos, and audio will appear here';

  @override
  String get goGenerate => 'Create now';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get sampleAccountQuestion =>
      'Is there an account you like and want to learn from...';

  @override
  String pointsSpent(int points) {
    return 'Spent $points points';
  }

  @override
  String get continueTask => 'Continue';

  @override
  String get download => 'Download';

  @override
  String get delete => 'Delete';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get accountManagement => 'Account management';

  @override
  String get wechatId => 'WeChat ID';

  @override
  String get douyin => 'Douyin';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirmationTitle => 'Sign out?';

  @override
  String get logoutDescription =>
      'Signing out won\'t delete any data.\nYou can sign in to this account again.';

  @override
  String get confirmLogout => 'Confirm sign out';

  @override
  String get logoutFailed => 'Unable to sign out. Try again later';

  @override
  String get regularUser => 'Regular user';

  @override
  String memberLevel(String level) {
    return 'Member $level';
  }

  @override
  String get upgradeMembership => 'Upgrade';

  @override
  String get goToLogin => 'Sign in';

  @override
  String get membershipStarter => 'Starter Inspiration';

  @override
  String get membershipPlus => 'Plus Creator';

  @override
  String get membershipPro => 'Pro Flagship';

  @override
  String get membershipMax => 'Max Studio';

  @override
  String get limitedDiscount => '40% off';

  @override
  String get perMonth => '/month';

  @override
  String membershipPointsValue(String value) {
    return 'Approx. ¥$value per 100 points';
  }

  @override
  String get pointsPerMonth => 'points/month';

  @override
  String membershipPointsBreakdown(int packagePoints, int giftPoints) {
    return 'Includes $packagePoints plan points + $giftPoints bonus points';
  }

  @override
  String get membershipCoreBenefits => 'Core membership benefits';

  @override
  String get benefitVoiceClone => 'Voice cloning enabled';

  @override
  String benefitConcurrentTasks(int count) {
    return 'Up to $count concurrent tasks';
  }

  @override
  String get benefitCharacters => 'Free and member characters';

  @override
  String get benefitWatermark => 'Watermark-free downloads';

  @override
  String get benefitVip => 'Dedicated VIP channel';

  @override
  String get benefitStoragePrefix => 'Member storage limit: ';

  @override
  String get openMembership => 'Subscribe now';

  @override
  String get membershipComingSoon => 'Membership purchases are coming soon';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get purchaseProcessing => 'Connecting to the App Store…';

  @override
  String get purchaseSuccess => 'Purchase complete. Your benefits are updated';

  @override
  String get purchaseCanceled => 'Purchase canceled';

  @override
  String get purchaseFailed =>
      'The purchase could not be completed. Try again later';

  @override
  String get storeUnavailable => 'The App Store is currently unavailable';

  @override
  String get storeProductUnavailable =>
      'This product was not found in the App Store. Check its configuration';

  @override
  String get appleProductIdMissing =>
      'This item does not have an Apple Product ID';

  @override
  String get restorePurchasesRequested =>
      'Purchases and membership benefits synced from your account';

  @override
  String get membershipPlansEmpty => 'No membership plans available';

  @override
  String get membershipPlansLoadFailed => 'Unable to load membership plans';

  @override
  String get rechargeAndPoints => 'Top up | Points details';

  @override
  String get rechargeAction => 'Top up';

  @override
  String get pointsDetailsTitle => 'Points details';

  @override
  String get rechargePointsPackage => 'Top up points';

  @override
  String get rechargedPoints => 'Purchased points';

  @override
  String get giftPoints => 'Bonus points';

  @override
  String get pointsPackage => 'Points package';

  @override
  String get pointPackagesEmpty => 'No point packages available';

  @override
  String get pointPackagesLoadFailed => 'Unable to load point packages';

  @override
  String get pointsUsageDescription =>
      'This credit allowance or plan works across POPi mobile, POPi.air, and POPi.TV, with balances synced in real time.';

  @override
  String get dailyFreePoints => 'Daily free points';

  @override
  String get seedanceTrial => 'Seedance 2.0 trial';

  @override
  String get samplePointsDate => '2026-09-02 09:46';

  @override
  String get pointsHistoryNotice =>
      'View point activity from the last 30 days. Updates may be delayed.';

  @override
  String get pointsLogEmpty => 'No point activity yet';

  @override
  String get pointsLogLoadFailed => 'Unable to load point activity';

  @override
  String get pointsLogUnknownSource => 'Points activity';

  @override
  String get retry => 'Retry';

  @override
  String get pointsBalance => 'balance';

  @override
  String get rechargeMembershipNotice =>
      'Note: Membership is required for member characters, watermark-free images and videos, and other benefits. Buying points alone does not include these benefits. Purchased points are valid for one year.';

  @override
  String get customerServiceContact => 'Customer service: 13100671900';

  @override
  String get rechargeAgreementPrefix => 'By topping up, you agree to the ';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get conjunctionAnd => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get nicknameRequiredLabel => 'Nickname*';

  @override
  String get nicknameHelp =>
      'Chinese, English, and numbers are supported. Up to 15 characters.';

  @override
  String get nicknameRequired => 'Enter a nickname';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileUpdateFailed =>
      'Unable to update your profile. Try again later';

  @override
  String get splashTagline => '“Helping people express themselves better”';
}
