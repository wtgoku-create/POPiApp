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
  String get roleGuideTitle => 'Start with characters';

  @override
  String get roleGuideDescription =>
      'Choose up to 6 characters\nto start a new project:';

  @override
  String get roleCastTitle => 'Choose your cast';

  @override
  String get roleCastDescription =>
      'Choose up to 3 characters\nfrom your project for the video:';

  @override
  String get roleTopicTitle => 'Find their next story';

  @override
  String get roleTopicDescription =>
      'POPi suggests 3 stories\nfor your characters:';

  @override
  String get roleProductionTitle => 'Create your video';

  @override
  String get roleProductionDescription =>
      'Choose a model and settings\nto bring your story to life:';

  @override
  String get roleCreateProject => 'Create project';

  @override
  String get roleGuideViewMore => 'View more';

  @override
  String roleSelectedCount(int count) {
    return ' ($count selected)';
  }

  @override
  String get roleChooseCast => 'Use this cast';

  @override
  String get roleSelectProjectFirst =>
      'Choose characters for your project first';

  @override
  String get roleSelectCastFirst => 'Choose your cast first';

  @override
  String get roleProjectLimit => 'Choose up to 6 project characters';

  @override
  String get roleCastLimit => 'Choose up to 3 cast members';

  @override
  String roleProjectName(String name) {
    return '$name\'s project';
  }

  @override
  String roleProjectCount(int count) {
    return '$count project characters';
  }

  @override
  String roleCastCount(int count) {
    return '$count cast members';
  }

  @override
  String get roleChooseStory => 'Choose this story';

  @override
  String get roleRefreshStories => 'Try another set';

  @override
  String get rolePreviousStory => 'Previous story';

  @override
  String get roleNextStory => 'Next story';

  @override
  String get roleStoryOverview => 'Story overview';

  @override
  String get roleModelParameters => 'Model / settings';

  @override
  String get roleModelPending => 'Model / settings (choose)';

  @override
  String get roleChooseParametersFirst => 'Choose a model and settings first';

  @override
  String get roleVideoPreference => 'Video preferences';

  @override
  String get roleImagePreference => 'Image preferences';

  @override
  String get roleModelSelection => 'Choose a model';

  @override
  String get roleResolution => 'Resolution';

  @override
  String get roleRatio => 'Aspect ratio';

  @override
  String get roleDimensions => 'Dimensions';

  @override
  String get roleQuantity => 'Quantity';

  @override
  String roleEstimatedPoints(int points) {
    return 'Estimated points: $points';
  }

  @override
  String get roleModelSoraDescription =>
      'OpenAI media generation with synchronized audio and video';

  @override
  String get roleModelVeoDescription =>
      'Google video model with cinematic quality and precise camera control';

  @override
  String get roleModelJimengDescription =>
      'ByteDance video model with consistent motion and image-to-video generation';

  @override
  String get roleModelKlingDescription =>
      'Kuaishou video model with natural physics and stable camera movement';

  @override
  String get roleModelViduDescription =>
      'ShengShu model with reference-based effects and material transfer';

  @override
  String get roleModelDiscount => '50% off';

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
    return 'Create a video using this plan.\nProject: $project\nProject characters: $roles\nCast: $cast\nTopic: $title\nStory overview: $story\nVideo model: $model\nVideo settings: $video\nImage settings: $image\nQuantity: $quantity';
  }

  @override
  String get roleExampleAlice => 'Alice';

  @override
  String get roleExampleErer => 'Erer';

  @override
  String get roleExampleHua => 'Hua Xileng';

  @override
  String get roleExampleDoudou => 'Doudou';

  @override
  String get roleExampleConfused => 'Little Dreamer';

  @override
  String get roleExampleStrawberry => 'Strawberry';

  @override
  String get roleExampleQiqi => 'Qiqi and Didi';

  @override
  String get roleExampleMermaid => 'Miss Mermaid';

  @override
  String get roleExampleDescription =>
      'A classmate, roommate, and witty best friend...';

  @override
  String get roleExampleStoryTitle1 =>
      'After graduation, I found my passion...';

  @override
  String get roleExampleStoryTitle2 => 'My roommate\'s secret plan';

  @override
  String get roleExampleStoryTitle3 => 'Today, I\'ll look after you';

  @override
  String get roleExampleStoryTitle4 => 'The first time I spoke my mind';

  @override
  String get roleExampleStoryTitle5 => 'Hot cocoa after a misunderstanding';

  @override
  String get roleExampleStoryTitle6 => 'One last little adventure together';

  @override
  String get roleExampleStory1 =>
      'He looks down at the pen in his hand, unable to write his plans for life after graduation. Laughter outside brings back memories of late nights finishing assignments together. A friend notices his hesitation and hands him a sketchbook filled with everyday moments. He realizes his passion has always been telling stories about the people around him. Together, they decide to shoot one final short film before graduation, turning their unspoken thoughts into a story and leaving their future selves a little courage.';

  @override
  String get roleExampleStory2 =>
      'Their roommate has been slipping out early and returning late. Worried, the friends decide to follow her, stumbling through one funny misunderstanding after another. Behind the classroom door, they discover a surprise farewell party. Photographs cover the walls, each carrying a thank-you she never quite managed to say aloud.';

  @override
  String get roleExampleStory3 =>
      'The friend who always takes care of everyone loses her confidence after a setback. Her companions quietly take over the little things: saving breakfast, waiting for her to come home, remembering a small wish. When she realizes she can be cared for too, she finally lets herself stop pretending to be fine.';

  @override
  String get roleExampleStory4 =>
      'An ordinary dinner turns into a conversation about unspoken dreams. Encouraged by her friends, she finally shares what she really wants to do. Nobody laughs or rushes her. They write down their wishes and promise to open them together a year later, to see where this small act of courage has taken them.';

  @override
  String get roleExampleStory5 =>
      'A careless remark leaves two best friends barely speaking. Their companions try to help, creating more confusion along the way. On a rainy evening, the two meet at their usual cafe. Over hot cocoa, an honest conversation reveals they were both waiting for the other to speak first.';

  @override
  String get roleExampleStory6 =>
      'Before moving out, the friends make a list of things to do together. The final wish is to watch a sunrise. Forgotten keys, a wrong turn, and a missed breakfast almost derail the trip. Standing in the morning light, they skip the goodbyes and simply promise another little adventure when they meet again.';

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
  String get confirmRoleChanges => 'Confirm changes';

  @override
  String get savingRoleChanges => 'Saving…';

  @override
  String get roleChangesSaved => 'Role profile saved';

  @override
  String get roleChangesSaveFailed =>
      'Could not save the role profile. Try again.';

  @override
  String get roleFieldRequired => 'This field is required';

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
  String get videoPlay => 'Play';

  @override
  String get videoPause => 'Pause';

  @override
  String get videoMute => 'Mute';

  @override
  String get videoUnmute => 'Unmute';

  @override
  String get videoSeek => 'Playback position';

  @override
  String get videoLoadFailed => 'Could not play this video';

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
  String get ipAccountsTitle => 'IP Account Management';

  @override
  String get loadingIpAccounts => 'Loading accounts';

  @override
  String get ipAccountsAll => 'All';

  @override
  String get ipAccountsRecent => 'Recently Used';

  @override
  String get ipAccountsPaused => 'Paused';

  @override
  String get ipAccountNormalStatus => 'Normal';

  @override
  String get ipAccountPausedStatus => 'Pause';

  @override
  String get noIpAccounts => 'No IP accounts yet';

  @override
  String get noRecentIpAccounts => 'No recently used accounts';

  @override
  String get noPausedIpAccounts => 'No paused accounts';

  @override
  String get ipAccountDetailsPending => 'Account details are not available yet';

  @override
  String get ipAccountsPending => 'IP accounts are not available yet';

  @override
  String get newConversation => 'New conversation';

  @override
  String get newSessionTitle => 'New conversation';

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
      'Douyin sign-in is unavailable. Check that Douyin is installed and the app is configured.';

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
  String get homeWelcomeGuest => 'Hi, I\'m POPi~';

  @override
  String homeWelcomeUser(String name) {
    return 'Hi, $name~';
  }

  @override
  String get homeWelcomeBody => 'Let\'s create something today';

  @override
  String get homeStartIp => 'Create a new IP account';

  @override
  String get homeStartRole => 'Start with a character';

  @override
  String get homeStartContent => 'Start with a topic, content or script';

  @override
  String homeBannerPage(int page, int total) {
    return 'Creative inspiration, image $page of $total';
  }

  @override
  String get homeGreetingBody => 'I\'ll help you\nbuild an account together!';

  @override
  String get ipGuideIntroduction => 'Introduction';

  @override
  String get ipGuideIntroBefore => 'Just ';

  @override
  String get ipGuideIntroFourSteps => '4 steps';

  @override
  String get ipGuideIntroAfter => '\nto create your IP account';

  @override
  String get ipGuideStart => 'Start creating';

  @override
  String ipGuideStep(int step) {
    return 'Step $step';
  }

  @override
  String get ipDirectionQuestion => 'What would you like to share over time?';

  @override
  String get ipFeelingQuestion => 'How should your audience feel?';

  @override
  String get ipPresentationQuestion => 'How should your account appear?';

  @override
  String get ipReviewQuestion => 'Your personal plan is ready to review~';

  @override
  String get ipNextFeelings => 'Next: audience feelings';

  @override
  String get ipNextPresentation => 'Next: presentation';

  @override
  String get ipNextReview => 'Next: review your plan';

  @override
  String get ipConfirmCreate => 'Confirm and create';

  @override
  String get ipReview => 'Review';

  @override
  String get ipContentDirection => 'Content direction';

  @override
  String get ipAudienceFeeling => 'Audience feelings';

  @override
  String get ipPresentation => 'Presentation';

  @override
  String get ipContentFormat => 'Content format';

  @override
  String get ipTargetAudience => 'Target audience';

  @override
  String get ipTargetAudienceValue =>
      'People who want to share this feeling with you';

  @override
  String get ipCustomHint => 'Something else, in my own words';

  @override
  String ipPrimarySelection(String label) {
    return 'Primary: $label';
  }

  @override
  String ipSecondarySelection(String label) {
    return 'Secondary: $label';
  }

  @override
  String get ipMaximumSelections =>
      'Choose up to two: a primary and a secondary';

  @override
  String get ipSelectDirection =>
      'Choose a content direction or write your own';

  @override
  String get ipSelectFeeling => 'Choose an audience feeling or write your own';

  @override
  String get ipSelectPresentation => 'Choose a presentation style';

  @override
  String get ipNotSelected => 'Not selected';

  @override
  String get ipAccountAvatar => 'Me';

  @override
  String get ipNewAccount => 'My new account';

  @override
  String get ipAccountProfile => 'IP profile';

  @override
  String get ipAccountNickname => 'Account nickname:';

  @override
  String get ipNicknameHint => 'Give your account a name';

  @override
  String get ipDirectionCampus => 'Campus';

  @override
  String get ipDirectionEmotion => 'Relationships';

  @override
  String get ipDirectionGrowth => 'Growth';

  @override
  String get ipDirectionCareer => 'Career';

  @override
  String get ipDirectionFamily => 'Family';

  @override
  String get ipDirectionHumor => 'Humor';

  @override
  String get ipDirectionMystery => 'Mystery';

  @override
  String get ipDirectionPets => 'Pets';

  @override
  String get ipDirectionKnowledge => 'Knowledge';

  @override
  String get ipFeelingAuthentic => 'Authentic';

  @override
  String get ipFeelingMoving => 'Moving';

  @override
  String get ipFeelingHealing => 'Healing';

  @override
  String get ipFeelingGripping => 'Gripping';

  @override
  String get ipFeelingDestiny => 'Destiny';

  @override
  String get ipFeelingSurprising => 'Surprising';

  @override
  String get ipFeelingAuthenticDescription =>
      'Natural stories that feel close to real life';

  @override
  String get ipFeelingMovingDescription =>
      'Touch the heart and bring a tear to the eye';

  @override
  String get ipFeelingHealingDescription =>
      'Warm, comforting moments to help people unwind';

  @override
  String get ipFeelingGrippingDescription =>
      'A compelling pace that keeps people watching';

  @override
  String get ipFeelingDestinyDescription =>
      'Encounters and bonds that feel meant to be';

  @override
  String get ipFeelingSurprisingDescription =>
      'Unexpected endings that surprise your audience';

  @override
  String get ipPresentationAiReal => 'AI human';

  @override
  String get ipPresentation2d => '2D animation';

  @override
  String get ipPresentation3d => '3D animation';

  @override
  String get ipPresentationLive => 'Live action';

  @override
  String get ipFormatShortFilm => 'Short film';

  @override
  String get ipFormatComicDrama => 'Comic drama';

  @override
  String get ipFormatInteractiveDrama => 'Interactive drama';

  @override
  String get ipFormatTalkingHead => 'Talking head';

  @override
  String ipGuideSessionPrompt(
    String name,
    String direction,
    String feelings,
    String presentation,
    String format,
    String audience,
  ) {
    return 'Help me create a new IP account.\nAccount nickname: $name\nContent direction: $direction\nAudience feelings: $feelings\nPresentation: $presentation\nContent format: $format\nTarget audience: $audience';
  }

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
  String get attachmentTitle => 'Add';

  @override
  String get attachmentCamera => 'Camera';

  @override
  String get attachmentConfirm => 'Confirm upload';

  @override
  String get attachmentLegalNotice =>
      'By uploading, you agree to the User Agreement and Privacy Policy. Please ensure you have the rights to use the uploaded materials.';

  @override
  String get galleryManageAccess => 'Manage accessible photos';

  @override
  String get galleryOpenSettings => 'Photo access settings';

  @override
  String get galleryAccessDenied => 'Photo access is disabled';

  @override
  String get galleryRestricted => 'Photo access is restricted on this device';

  @override
  String get galleryEmpty => 'No accessible photos';

  @override
  String get galleryLoadFailed => 'Could not load photos. Please try again';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get sendMessage => 'Send message';

  @override
  String get searchConversations => 'Search conversations';

  @override
  String get newIpProject => 'New IP project';

  @override
  String get drawerSessions => 'Conversations';

  @override
  String sessionItemOptions(String name) {
    return 'Options for conversation $name';
  }

  @override
  String projectCount(int count) {
    return 'Projects ($count)';
  }

  @override
  String get projectOptions => 'Project options';

  @override
  String get expandAllProjects => 'Expand all projects';

  @override
  String get collapseAllProjects => 'Collapse all projects';

  @override
  String get loginToViewProjects => 'Log in to view projects';

  @override
  String get noProjects => 'No projects yet';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get loadingProjects => 'Loading projects';

  @override
  String get loadingProjectSessions => 'Loading conversations';

  @override
  String get loadingRoles => 'Loading roles';

  @override
  String get loadingAssets => 'Loading assets';

  @override
  String get projectsLoadFailed => 'Could not load projects';

  @override
  String get projectSessionsLoadFailed => 'Could not load conversations';

  @override
  String projectItemOptions(String name) {
    return 'Options for $name';
  }

  @override
  String get renameProjectItem => 'Rename';

  @override
  String get projectItemName => 'Name';

  @override
  String get pinSession => 'Pin conversation';

  @override
  String get unpinSession => 'Unpin conversation';

  @override
  String deleteProjectConfirm(String name) {
    return 'Delete $name and all its conversations?';
  }

  @override
  String deleteSessionConfirm(String name) {
    return 'Delete conversation $name?';
  }

  @override
  String get projectItemRenamed => 'Renamed successfully';

  @override
  String get projectItemDeleted => 'Deleted successfully';

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
  String get imageSavedToPhotos => 'Image saved to Photos';

  @override
  String get imageSaveFailed => 'Could not save the image. Try again later.';

  @override
  String get imageSaveAccessDenied =>
      'Allow adding photos in system settings to save images.';

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
  String get socialBound => 'Linked';

  @override
  String get socialUnbound => 'Not linked';

  @override
  String get socialBindingLoading => 'Pending';

  @override
  String get socialBindingLoadFailed => 'Failed. Retry';

  @override
  String get socialBindingSucceeded => 'Account linked';

  @override
  String get socialBindingCanceled => 'Linking canceled';

  @override
  String get socialBindingUnavailable =>
      'Authorization is unavailable. Check that the app is installed and authorization is configured.';

  @override
  String get socialBindingFailed => 'Could not link account. Please try again.';

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
  String get webPageLoadFailed => 'Could not load this page. Please try again';

  @override
  String get webPageLoading => 'Loading page';

  @override
  String get webPageOpenInBrowser => 'Open in browser';

  @override
  String get webPageBrowserRequired => 'Please view this page in your browser';

  @override
  String get webPageRefresh => 'Refresh page';

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
