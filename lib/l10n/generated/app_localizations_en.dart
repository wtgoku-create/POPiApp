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
  String get graphicalCaptcha => 'Image verification';

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
  String get otherLoginMethods => 'Other sign-in methods';

  @override
  String get wechatLogin => 'Continue with WeChat';

  @override
  String get loginAgreement =>
      'I have read and agree to the User Agreement and Privacy Policy';

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
  String get logoutDescription =>
      'You\'ll need to sign in again to continue using POPi';

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
  String get rechargeAndPoints => 'Top up | Points details';

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
  String get splashTagline => 'Build something useful.';
}
