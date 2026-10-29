// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get v2NoConversationSelected => 'No conversation selected';

  @override
  String get appTitle => 'POPi';

  @override
  String get hideKeyboard => 'Hide keyboard';

  @override
  String get roleGuideTitle => 'Start with characters';

  @override
  String get roleNotReadyForVideo =>
      'This character\'s profile or reference images are not ready';

  @override
  String get roleRequestFailed =>
      'Could not complete the creation request. Try again';

  @override
  String get roleStoryRequestFailed => 'Could not complete the story request';

  @override
  String get roleLoadingStories => 'Finding stories...';

  @override
  String get roleNoStories => 'No story suggestions yet';

  @override
  String get roleAccountFallbackTitle => 'IP account';

  @override
  String get roleNoVideoModels => 'No video models available';

  @override
  String get roleModelConfigured => 'Model configured';

  @override
  String get roleTaskPaused => 'Creation paused';

  @override
  String get roleStatusPausing => 'Pausing';

  @override
  String get roleTaskPausing => 'Pausing creation...';

  @override
  String get roleTaskCanceling => 'Canceling creation...';

  @override
  String get roleStatusPaused => 'Paused';

  @override
  String get roleStatusCanceling => 'Canceling';

  @override
  String get roleGenerationPausedDescription =>
      'Your current plan is saved. You can resume creation.';

  @override
  String get chatTaskCanceling => 'Canceling after the current stage';

  @override
  String get rolePauseProduction => 'Pause creation';

  @override
  String get roleResumeProduction => 'Resume creation';

  @override
  String get roleConfirmVideo => 'Confirm video generation';

  @override
  String get roleGuideDescription =>
      'Choose up to 5 characters\nto start a project conversation';

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
  String get roleConfirmSelection => 'Confirm selection';

  @override
  String roleSelectionLimit(int count) {
    return 'Choose up to $count characters';
  }

  @override
  String get removeRole => 'Remove role';

  @override
  String get removeAsset => 'Remove asset';

  @override
  String assetSelectionLimit(int count) {
    return 'Choose up to $count media items';
  }

  @override
  String get chatRolePrompt => 'Create using the selected characters.';

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
  String get roleProjectLimit => 'Choose up to 5 project characters';

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
  String get roleReconfirmVideo => 'Confirm video again';

  @override
  String get rolePreviousStory => 'Previous story';

  @override
  String get roleNextStory => 'Next story';

  @override
  String get roleStoryOverview => 'Story overview';

  @override
  String get roleSwitchProject => 'Switch project';

  @override
  String get roleMyProjects => 'My IP projects';

  @override
  String get roleEditProjectRoles => 'Edit project characters';

  @override
  String get roleViewProfiles => 'View character profiles';

  @override
  String roleProfilePage(int index, int total) {
    return 'Character profile $index/$total';
  }

  @override
  String get roleFullProfile => 'View full character profile';

  @override
  String get roleCollapseProfile => 'Collapse full character profile';

  @override
  String roleFullProfileVersion(String version) {
    return 'View full character profile $version';
  }

  @override
  String get rolePreviousProfile => 'Previous character profile';

  @override
  String get roleNextProfile => 'Next character profile';

  @override
  String get roleDetailedStory => 'Full story';

  @override
  String get roleStoryDevelopment => 'Plot development';

  @override
  String get roleStoryContent => 'Main content';

  @override
  String get roleProduceVideo => 'Create video';

  @override
  String get roleStartCreating => 'Start creating';

  @override
  String get roleViewPlan => 'View plan';

  @override
  String get roleGeneratingTitle => 'Creating your video...';

  @override
  String get roleGeneratingDescription =>
      'Stay here to wait\nor view the plan in chat';

  @override
  String get roleGeneratedTitle => 'Creation complete!';

  @override
  String get roleGeneratedDescription =>
      'Refine it in chat\nor explore a new idea with Agent';

  @override
  String get roleGenerationFailedTitle => 'Creation interrupted';

  @override
  String get roleGenerationFailedDescription =>
      'Your plan is saved\nRetry or adjust it to continue';

  @override
  String get roleGenerationCanceledTitle => 'Production stopped';

  @override
  String get roleGenerationCanceledDescription =>
      'Your plan is saved\nAdjust it and start again';

  @override
  String get roleTaskRunning => 'Creating your video...';

  @override
  String get roleTaskCompleted => 'Task completed';

  @override
  String get roleTaskFailed => 'Creation failed. Try again.';

  @override
  String get roleTaskCanceled => 'Task stopped';

  @override
  String get roleTaskExecuting => 'Running';

  @override
  String get roleStatusCompleted => 'Completed';

  @override
  String get roleStatusFailed => 'Failed';

  @override
  String get roleStatusCanceled => 'Stopped';

  @override
  String get roleStageCharacters => 'Characters';

  @override
  String get roleStageScript => 'Script';

  @override
  String get roleStageStoryboard => 'Storyboard';

  @override
  String get roleStageVideo => 'Video';

  @override
  String get roleStageReview => 'Review';

  @override
  String get roleWorkGenerating => 'Creating your video...';

  @override
  String get roleStopProduction => 'Stop production';

  @override
  String get roleStopProductionTitle => 'Stop this production?';

  @override
  String get roleStopProductionDescription =>
      'Your characters, story and model settings will be kept so you can start again.';

  @override
  String get roleKeepGenerating => 'Keep waiting';

  @override
  String get roleContinueCreating => 'Continue creating';

  @override
  String get roleChatInSession => 'Chat with Agent';

  @override
  String get roleProjectSession => 'Project conversation';

  @override
  String get roleScriptContent => 'Script';

  @override
  String get chatVideoProgress => 'Video generation progress';

  @override
  String get chatStoryboardReview =>
      'Storyboard ready, awaiting video confirmation';

  @override
  String get chatTaskPausing => 'Pausing after the current stage';

  @override
  String get chatStageGenerateVideo => 'Generate video';

  @override
  String get chatStageInspectResult => 'Inspect result';

  @override
  String get roleStoryboardContent => 'Storyboard video prompt';

  @override
  String roleStoryboardShot(int index, String duration) {
    return 'Shot $index · $duration s';
  }

  @override
  String get roleVideoModelPrompt => 'Video model prompt';

  @override
  String get videoFullscreen => 'Play fullscreen';

  @override
  String get rolePreviewNotice => 'Interaction preview · No points charged';

  @override
  String get rolePreviewCover => 'Example cover';

  @override
  String get roleEstimatePending =>
      'Choose a model and settings to see a points estimate';

  @override
  String get roleEstimatePreview =>
      'The final quote applies when production is connected';

  @override
  String roleStoryPosition(int index, int total) {
    return '$index/$total';
  }

  @override
  String get roleExampleDevelopment1 =>
      'An unwritten graduation plan leads to a friend\'s sketchbook and a decision to make a short film. Revisiting those memories helps the character find a passion.';

  @override
  String get roleExampleDevelopment2 =>
      'A roommate\'s strange behavior prompts a secret investigation. A series of comic misunderstandings ends with a surprise farewell party in their classroom.';

  @override
  String get roleExampleDevelopment3 =>
      'A setback breaks through her usual brave face. Her friends support her in small everyday ways until she feels ready to share how tired she is.';

  @override
  String get roleExampleDevelopment4 =>
      'Dinner-table jokes give way to attentive listening. She shares her dream, the others share theirs, and they make a promise to meet again in a year.';

  @override
  String get roleExampleDevelopment5 =>
      'A misunderstanding pulls two friends apart and well-meant interventions make it worse. A rainy-day encounter over hot cocoa finally gives them space to talk.';

  @override
  String get roleExampleDevelopment6 =>
      'Watching a sunrise is the last wish before moving away. Small mishaps bring the friends closer, and their goodbye becomes a promise to meet again.';

  @override
  String get roleExampleContent1 =>
      'Shot 1: A pen hovers over a blank graduation plan beside the window.\nShot 2: Sketchbook photographs alternate with campus memories.\nShot 3: The friends raise a camera and film their first scene at sunset.';

  @override
  String get roleExampleContent2 =>
      'Shot 1: The roommate slips out as friends peek around the door.\nShot 2: Their clumsy investigation takes them across campus.\nShot 3: A classroom door opens onto photographs and party lights.';

  @override
  String get roleExampleContent3 =>
      'Shot 1: She sits at a desk and lets her forced smile fade.\nShot 2: Breakfast, patient waiting and notes show her friends\' care.\nShot 3: Surrounded by friends, she rests her head on a shoulder.';

  @override
  String get roleExampleContent4 =>
      'Shot 1: Dinner-table laughter settles as everyone listens.\nShot 2: Each friend writes a dream on a slip of paper.\nShot 3: They seal the notes in a box dated one year from today.';

  @override
  String get roleExampleContent5 =>
      'Shot 1: Two friends pass silently in a hallway.\nShot 2: Rain falls outside a cafe while cocoa steams on the table.\nShot 3: After an honest conversation, they leave under one umbrella.';

  @override
  String get roleExampleContent6 =>
      'Shot 1: A wish list has one unchecked item: watch a sunrise.\nShot 2: Forgotten keys and wrong turns turn into shared laughter.\nShot 3: They stand together in morning light and promise to reunite.';

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
  String get roleDuration => 'Duration';

  @override
  String get roleNoImageModels => 'No image models available';

  @override
  String get roleDurationAutomatic => 'Automatic';

  @override
  String get roleDurationCustom => 'Custom';

  @override
  String roleDurationSeconds(String seconds) {
    return '${seconds}s';
  }

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
  String get roleEditCreationProfile => 'Edit role for this creation';

  @override
  String get roleEditCreationArchive => 'Edit profile for this creation';

  @override
  String get roleCreationEditTitle => 'Adjust the role for this creation';

  @override
  String get roleCreationEditDescription =>
      'Edit the description, appearance, personality, expression style, audience and content tags.';

  @override
  String get roleFieldInvalidFormat => 'Invalid field format';

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
  String get ipProjects => 'IP projects';

  @override
  String get teachingCenter => 'Learning center';

  @override
  String get ipAccountsTitle => 'IP Account Management';

  @override
  String get deleteIpAccountTitle => 'Delete this IP account?';

  @override
  String get deleteIpAccountDescription =>
      'The account will be archived and removed from the account list. Works, conversations and account data will be preserved.';

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
  String get ipAccountHomeTitle => 'Account Home';

  @override
  String get ipAccountPreferences => 'Account Preferences';

  @override
  String get accountCreate => 'Create account';

  @override
  String get accountArchived => 'Archived';

  @override
  String get accountActive => 'Active';

  @override
  String get accountArchive => 'Archive account';

  @override
  String get accountRestore => 'Restore account';

  @override
  String get accountArchiveConfirm =>
      'Creations, conversations and account details will be kept. You can restore this account at any time.';

  @override
  String get accountMemory => 'Account memory';

  @override
  String get accountUserPrompt => 'Account Positioning';

  @override
  String get accountPositioningHint =>
      'Enter the account\'s theme, style and creative direction';

  @override
  String get accountConstraints => 'Creative constraints';

  @override
  String get accountCustomOption => 'Custom option';

  @override
  String get accountInputInvalid =>
      'Enter a value within the selection and length limits';

  @override
  String get accountTitleInvalid =>
      'Enter an account name of up to 15 characters';

  @override
  String get accountRenameTitle => 'Rename project';

  @override
  String accountRenameConfirm(String title) {
    return 'Change the account nickname to:\n$title';
  }

  @override
  String get accountArchives => 'Creation archives';

  @override
  String get accountArchiveSearch => 'Search titles or summaries';

  @override
  String get accountLoadMore => 'Load more';

  @override
  String get accountArchiveVersion => 'Version';

  @override
  String get accountArchiveSummary => 'Summary';

  @override
  String get accountArchiveBrief => 'Brief';

  @override
  String get accountArchiveTopic => 'Topic';

  @override
  String get accountArchiveScript => 'Script';

  @override
  String get accountArchiveStoryboard => 'Storyboard video prompt';

  @override
  String get accountArchiveCast => 'Cast snapshot';

  @override
  String get accountArchiveGeneration => 'Generation parameters';

  @override
  String get accountOpenConversation => 'View conversation';

  @override
  String get ipAccountPositioning => 'Account Positioning';

  @override
  String get ipAccountFieldEmpty => 'Not set';

  @override
  String get ipAccountEdit => 'Edit';

  @override
  String get ipAccountSave => 'Save';

  @override
  String get ipAccountSaved => 'Account details saved';

  @override
  String get ipAccountLoadFailed =>
      'Could not load account details. Please retry.';

  @override
  String get ipAccountResourcesFailed =>
      'Could not load project assets and roles';

  @override
  String get ipAccountAssets => 'Project Assets';

  @override
  String get ipAccountRoles => 'Project Roles';

  @override
  String get ipAccountNoAssets => 'No creations yet';

  @override
  String get ipAccountNoRoles => 'No project roles yet';

  @override
  String get ipAccountCountSeparator => ': ';

  @override
  String get ipAccountAssetsEmptyPrompt =>
      'No creations yet. Start creating with your Agent.';

  @override
  String get ipAccountRolesEmptyPrompt =>
      'Add roles to build your creative world.';

  @override
  String get ipAccountManageRoles => 'Manage Project Roles';

  @override
  String get ipAccountRoleLimit => 'Add up to 20 roles';

  @override
  String get ipAccountPublish => 'Create Content';

  @override
  String get ipAccountPublishEstimate => 'About 1 min';

  @override
  String get ipAccountPublishReady =>
      'Your account is ready. Start with a topic, idea, script, or material.';

  @override
  String get ipAccountStartContent => 'Start New Content';

  @override
  String get ipAccountContinueConversation => 'Continue Conversation';

  @override
  String get ipAccountStartPrompt =>
      'Help me create new content based on this account\'s positioning.';

  @override
  String get ipAccountUnavailable => 'Account is paused';

  @override
  String get ipAccountsPending => 'IP accounts are not available yet';

  @override
  String get newConversation => 'New conversation';

  @override
  String get newSessionTitle => 'New project';

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
  String get imageShareFailed => 'Could not share image. Please try again';

  @override
  String get mediaShareFailed => 'Could not share media. Please try again';

  @override
  String mediaPreviewPosition(int index, int count) {
    return 'Item $index of $count';
  }

  @override
  String imagePreviewPosition(int index, int count) {
    return 'Image $index of $count';
  }

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
  String get activities => 'Activities';

  @override
  String get activityCenter => 'Activity Center';

  @override
  String get activityEmpty => 'No activities available';

  @override
  String get activityUntitled => 'Activity';

  @override
  String get activityNoDescription => 'No activity details available';

  @override
  String get activityLoadFailed =>
      'Unable to load activities. Please try again';

  @override
  String get activityUnavailable =>
      'This activity has ended or is not available yet';

  @override
  String get activityOfficialCode => 'Official redemption code';

  @override
  String get activityCodePlaceholder => 'Enter redemption code';

  @override
  String get activityOrderNumber => 'Order number';

  @override
  String get activityOrderPlaceholder => 'Paste your Douyin order number';

  @override
  String activityMemberRestriction(String levels) {
    return 'This activity is limited to $levels';
  }

  @override
  String activityMemberLevel(int level) {
    return 'Membership level $level';
  }

  @override
  String get activityExchangeSuccess => 'Redeemed successfully';

  @override
  String get activityExchangeFailed =>
      'Unable to redeem. Please try again later';

  @override
  String get activityRefreshFailed =>
      'Redeemed successfully. Membership information could not refresh; check again later';

  @override
  String get activityQrTitle => 'Activity QR code';

  @override
  String get activityFinalConfirmation => 'Final confirmation';

  @override
  String get activityRefundNotice =>
      'Once this membership benefit is claimed, the course is considered redeemed and used, and you will no longer be able to request a refund from POPi. To confirm that you fully understand this rule, enter the following text:';

  @override
  String get activityConfirmationPhrase =>
      'I understand this redemption is non-refundable';

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
  String imageUploadProgress(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get imageUploadProcessing => 'Processing';

  @override
  String get imageUploadFailed => 'Upload failed';

  @override
  String get imageUploadComplete => 'Uploaded';

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
  String get ipGuideIntroFiveSteps => '5 steps';

  @override
  String get ipDraftTitle => 'Continue your draft or create a new IP?';

  @override
  String get ipDraftDetected => 'An account positioning draft was found.';

  @override
  String get ipDraftDescription =>
      'Continue to return to your saved step. Starting again replaces this draft. Existing projects, content, and assets will be kept.';

  @override
  String get ipDraftRestart => 'Start again';

  @override
  String get ipDraftResume => 'Continue draft';

  @override
  String get ipDraftSaveFailed => 'Could not save your draft. Please retry.';

  @override
  String get ipNextAudience => 'Next: Target audience';

  @override
  String get ipAudienceQuestion => 'Who is your account for?';

  @override
  String get ipSelectAudience => 'Choose an audience or enter your own';

  @override
  String get ipSelectNickname => 'Enter a name for your account';

  @override
  String get ipReselect => 'Choose again';

  @override
  String get ipCreating => 'Creating...';

  @override
  String get ipCreateFailed =>
      'Creation is incomplete. Your draft is saved. Please retry.';

  @override
  String get ipCreateSuccess => 'Account created!';

  @override
  String get ipCreateSuccessDescription =>
      'Every piece of content you publish will build your account here.';

  @override
  String get ipCreateFirstRole => 'Create your first character';

  @override
  String get ipCreateFirstContent => 'Make your first content';

  @override
  String get ipOpenProject => 'Open account project';

  @override
  String get ipFirstRolePrompt =>
      'Help me create the first character based on this account\'s positioning.';

  @override
  String get ipFirstContentPrompt =>
      'Help me make the first piece of content based on this account\'s positioning.';

  @override
  String get ipAudienceStudents => 'Students';

  @override
  String get ipAudienceWorkers => 'Professionals';

  @override
  String get ipAudienceFamilies => 'Families';

  @override
  String get ipAudienceAnimeFans => 'Anime fans';

  @override
  String get ipAudiencePetLovers => 'Pet lovers';

  @override
  String get ipAudienceSeniors => 'Seniors';

  @override
  String get ipAudienceStudentsDescription =>
      'Campus life, learning, and the interests of young people';

  @override
  String get ipAudienceWorkersDescription =>
      'Work life, career growth, and everyday pressures';

  @override
  String get ipAudienceFamiliesDescription =>
      'Parenting, family life, and spending time with children';

  @override
  String get ipAudienceAnimeFansDescription =>
      'Anime characters, fantasy stories, and creative worlds';

  @override
  String get ipAudiencePetLoversDescription =>
      'Pets, playful moments, and comforting characters';

  @override
  String get ipAudienceSeniorsDescription =>
      'Healthy living, hobbies, and life after retirement';

  @override
  String get ipPresentationPets => 'Anthropomorphic pets';

  @override
  String get ipPresentationClay => 'Clay animation';

  @override
  String get ipPresentationInk => 'Chinese ink painting';

  @override
  String get ipVisualStyle => 'Visual style';

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
  String get composerRunning => 'Session is running';

  @override
  String get sessionWelcomeTitle => 'Hi there!';

  @override
  String get sessionWelcomeBody => 'Tell me, what would you like to create?';

  @override
  String get composerExpandInput => 'Expand input';

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
  String get attachmentFeaturePending => 'Feature under development';

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
  String get drawerNewConversation => 'New project chat';

  @override
  String get drawerViewAll => 'View all';

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
  String get notificationSystem => 'System';

  @override
  String get notificationPersonal => 'Personal';

  @override
  String get notificationNew => 'NEW';

  @override
  String get notificationUnread => 'Unread';

  @override
  String get notificationUntitled => 'Notification';

  @override
  String get notificationLearnMore => 'Learn more';

  @override
  String get notificationDetail => 'Notification Details';

  @override
  String get notificationEmpty => 'No notifications yet';

  @override
  String get notificationLoadFailed =>
      'Could not load notifications. Please retry.';

  @override
  String get notificationLoadMore => 'Load more';

  @override
  String get notificationLoadMoreFailed =>
      'Could not load more notifications. Retry';

  @override
  String get notificationReadFailed =>
      'Could not mark as read. Reopen the notification to retry.';

  @override
  String get notificationLoginRequired => 'Sign in to view notifications';

  @override
  String get notificationImageFailed => 'Could not load image';

  @override
  String get notificationViewImage => 'View notification image';

  @override
  String notificationDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

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
  String get creationHistoryLoadFailed => 'Unable to load creation history';

  @override
  String get searchCreationHistory => 'Search creation history';

  @override
  String get noMatchingHistory => 'No matching history';

  @override
  String get clearSearch => 'Clear search';

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
  String get sessionArtifactExported => 'Document exported';

  @override
  String get sessionArtifactExportFailed =>
      'Could not export the document. Try again later.';

  @override
  String get sessionArtifactSaved => 'File saved';

  @override
  String get sessionArtifactSaveFailed =>
      'Could not save the file. Try again later.';

  @override
  String get imageSavedToPhotos => 'Image saved to Photos';

  @override
  String get imageSaveFailed => 'Could not save the image. Try again later.';

  @override
  String get imageSaveAccessDenied =>
      'Allow adding photos in system settings to save images.';

  @override
  String get videoSavedToPhotos => 'Video saved to Photos';

  @override
  String get videoSaveFailed => 'Could not save the video. Try again later.';

  @override
  String get videoSaveAccessDenied =>
      'Allow adding photos in system settings to save videos.';

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
  String get cancelAccount => 'Delete account';

  @override
  String get cancelAccountTitle => 'Delete your account?';

  @override
  String get cancelAccountDescription =>
      'This cannot be undone. You will no longer be able to sign in, and all devices will be signed out.\nYour phone number and linked accounts cannot automatically register a new account. Historical data and works will be retained.';

  @override
  String get confirmCancelAccount => 'Delete account';

  @override
  String get cancelAccountSucceeded => 'Account deleted successfully';

  @override
  String get cancelAccountFailed =>
      'Unable to delete your account. Try again later';

  @override
  String get regularUser => 'Regular user';

  @override
  String memberLevel(String level) {
    return '$level member';
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
  String get paymentTitle => 'Confirm payment';

  @override
  String get paymentChooseMethod => 'Payment method';

  @override
  String get paymentWechat => 'WeChat Pay';

  @override
  String get paymentAlipay => 'Alipay';

  @override
  String get paymentConfirm => 'Confirm payment';

  @override
  String get paymentAmount => 'Payment amount';

  @override
  String get paymentPerYear => '/year';

  @override
  String get paymentPoints => 'points';

  @override
  String paymentGrantPoints(int points) {
    return 'Points granted: $points';
  }

  @override
  String get paymentCatalogPrice =>
      'Plan price. Your order determines the final charge';

  @override
  String get paymentCheckAgain => 'Check again';

  @override
  String get paymentProcessing =>
      'Payment is processing. Benefits will update once delivered';

  @override
  String get paymentCanceledPending =>
      'Payment canceled. Order status is awaiting confirmation';

  @override
  String get paymentUnknown =>
      'Payment status is unavailable. Check your bill before paying again';

  @override
  String get paymentNotCompleted =>
      'Order incomplete or refunded. Benefits have not been confirmed';

  @override
  String get paymentUnavailable =>
      'Payment service is unavailable. Try again later';

  @override
  String get paymentAppNotInstalled => 'Not installed or unavailable';

  @override
  String get paymentRetry => 'Retry';

  @override
  String get paymentDone => 'Done';

  @override
  String get paymentOrderNumber => 'Order number';

  @override
  String get paymentCopyOrder => 'Copy order number';

  @override
  String get paymentOrderCopied => 'Order number copied';

  @override
  String get paymentPendingOrders => 'Other unconfirmed orders';

  @override
  String get paymentNewPurchase => 'Buy again';

  @override
  String get paymentNewPurchaseWarning =>
      'The original order may still be processing. Check your WeChat or Alipay bill first. Buying again creates a new order and may result in a duplicate charge.';

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
  String get membershipCurrentPlan => 'Current plan';

  @override
  String get membershipBuyNow => 'Buy now';

  @override
  String membershipAlreadyMember(String level) {
    return 'You\'re already $level';
  }

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
      'This credit allowance or plan works across POPi mobile, POPi.Art, and POPi.TV, with balances synced in real time.';

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
  String get aboutPopiAi => 'About POPi AI';

  @override
  String get privacyConsentTitle => 'Terms and Privacy';

  @override
  String get privacyConsentMessage =>
      'Welcome to POPi! Before using the app, please read our User Agreement and Privacy Policy to understand how we collect, use and protect your personal information, and the rights available to you.\n\nFor sign-in, AI creation and saving content, we process account information, content you submit, and necessary device and log information as described in the policy. Permissions such as photo library access are requested when you use the relevant features.\n\nBy tapping “Agree & Continue”, you confirm that you have read and agree to these terms and policies.';

  @override
  String get privacyConsentAccept => 'Agree & Continue';

  @override
  String get privacyConsentDecline => 'Disagree';

  @override
  String get privacyConsentRequired =>
      'Please read and agree to the User Agreement and Privacy Policy to use POPi.';

  @override
  String get privacyConsentReview => 'Review Terms and Privacy';

  @override
  String get privacyConsentSaveFailed =>
      'Unable to save your choice. Please tap Agree & Continue again.';

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

  @override
  String get chatThinking => 'POPi is working…';

  @override
  String get chatQueued => 'Queued';

  @override
  String get chatWaitingExternal => 'Waiting for results';

  @override
  String get chatCanceling => 'Stopping';

  @override
  String get chatTopicSelected => 'Selected story';

  @override
  String get chatTopicConfirmed => 'Topic confirmed';

  @override
  String get chatCollapseStory => 'Collapse story';

  @override
  String get chatExpandStory => 'Expand story';

  @override
  String get chatGenerationConfirmed => 'Generation plan confirmed';

  @override
  String get chatGenerationCanceled => 'Generation plan canceled';

  @override
  String get chatReferenceImage => 'Reference image';

  @override
  String get chatImageStyle => 'Image style';

  @override
  String get chatStyleLibrary => 'Style library';

  @override
  String get chatStyleUnrestricted => 'Unrestricted style';

  @override
  String get chatUnrestrictedStyle => 'Unrestricted style';

  @override
  String get chatGenerationRequirements => 'Additional requirements';

  @override
  String get chatInvalidGeneration =>
      'Check the model, parameters and reference materials';

  @override
  String get chatUnavailable => 'Unavailable';

  @override
  String get chatGenerationTask => 'Generation task';

  @override
  String get chatExpandTask => 'Expand task';

  @override
  String get chatCollapseTask => 'Collapse task';

  @override
  String get chatGenerationWorking => 'Generating...';

  @override
  String get chatGenerationWorkingHint => 'Creating your work...';

  @override
  String get chatGenerationTaskCompleted => 'Task completed';

  @override
  String get chatImageGenerationFailed => 'Image generation failed';

  @override
  String get chatVideoGenerationFailed => 'Video generation failed';

  @override
  String get chatTextGenerationTimeout =>
      'Text generation timed out. Please try again';

  @override
  String get chatTextGenerationFailed =>
      'Text generation failed. Please try again';

  @override
  String get chatScriptGenerationFailed =>
      'Script generation failed. Please try again';

  @override
  String get chatTopicGenerationFailed =>
      'Topic generation failed. Please try again';

  @override
  String get chatResultCheckFailed =>
      'The video integrity check failed. The generated result has been kept';

  @override
  String get chatOutputValidationFailed =>
      'The generated result failed validation. Please try again';

  @override
  String get chatStoryboardMissing =>
      'The saved storyboard is missing. Confirm the storyboard before generating';

  @override
  String get chatVideoMissing =>
      'The generated video could not be found. Please try again';

  @override
  String get chatTaskInputChanged =>
      'The creation content has changed. Confirm the generation plan again';

  @override
  String get chatTaskConfirmationMismatch =>
      'The storyboard version does not match the confirmation. Confirm the storyboard again';

  @override
  String get chatVideoPromptInvalid =>
      'The generation prompt is invalid. Update the content and confirm again';

  @override
  String get chatTaskResultUnavailable =>
      'The generated result is temporarily unavailable. Please try again later';

  @override
  String get chatTaskSubmissionFailed =>
      'The generation task could not be submitted. Please try again later';

  @override
  String get chatTaskServiceUnavailable =>
      'The generation service is temporarily unavailable. Please try again later';

  @override
  String get chatRoleReferenceUnavailable =>
      'The character reference image is unavailable. Update the image and select the cast again before generating';

  @override
  String get chatProductionPlan => 'Production plan';

  @override
  String get chatPlanCast => 'Cast';

  @override
  String get chatPlanStory => 'Selected story';

  @override
  String get chatPlanHighlight => 'Core highlight';

  @override
  String get chatPlanConfiguration => 'Model configuration';

  @override
  String get chatPlanModel => 'Model';

  @override
  String get chatPlanPoints => 'Estimated points';

  @override
  String chatPlanCredits(String points) {
    return '$points points';
  }

  @override
  String get chatReviseContent => 'Revise content';

  @override
  String chatRevisePrompt(String title) {
    return 'Please revise $title: ';
  }

  @override
  String get chatBeforeChange => 'Before';

  @override
  String get chatAfterChange => 'After';

  @override
  String get chatCompleteRole => 'Create character';

  @override
  String get chatConfirmProfileUpdate => 'Update profile';

  @override
  String get chatRoleCreated => 'Character draft created';

  @override
  String get chatRoleUpdated => 'Character profile updated';

  @override
  String get chatRolePublished => 'Character profile published';

  @override
  String get chatViewRoleLibrary => 'View in character library';

  @override
  String get chatViewRoleProfile => 'View full profile';

  @override
  String get chatCastRole => 'Cast';

  @override
  String get chatCastUnmatched => 'Unmatched';

  @override
  String chatCastMultiple(int count) {
    return '$count roles';
  }

  @override
  String get chatConfirmCast => 'Confirm cast';

  @override
  String get chatCastRoleUnavailable =>
      'This role is unavailable. Choose a readable role with a saved profile.';

  @override
  String get chatRoleActive => 'Published';

  @override
  String get chatRoleDraft => 'Draft';

  @override
  String get chatExpandProgress => 'Expand progress';

  @override
  String get chatCollapseProgress => 'Collapse progress';

  @override
  String get chatThoughtProcess => 'Thought process';

  @override
  String get chatStepPrepare => 'Prepare';

  @override
  String get chatStepProcess => 'Process request';

  @override
  String get chatStepReply => 'Generate reply';

  @override
  String get chatStepSaveText => 'Save content';

  @override
  String get chatStepPreparePlan => 'Prepare generation plan';

  @override
  String get chatStepAnalyze => 'Analyze creative requirements';

  @override
  String get chatStepReadRole => 'Read character profiles';

  @override
  String get chatStepReadContext => 'Review creative context';

  @override
  String get chatStepTopics => 'Suggest topics';

  @override
  String get chatStepPrepareRole => 'Prepare character plan';

  @override
  String get chatStepSaveRole => 'Save character draft';

  @override
  String get chatStepPublishRole => 'Publish character';

  @override
  String get chatStepVerifyResult => 'Verify results';

  @override
  String get chatStepGenerateImage => 'Generate image';

  @override
  String get chatStepGenerateVideo => 'Generate video';

  @override
  String get chatStepGenerateAudio => 'Generate audio';

  @override
  String get chatStepSyncResult => 'Sync results';

  @override
  String get chatPreparing => 'Preparing…';

  @override
  String get chatProcessing => 'Processing your request';

  @override
  String get chatGeneratingReply => 'Generating response…';

  @override
  String get chatSavingArtifact => 'Saving output…';

  @override
  String get chatPlanningGeneration => 'Preparing the generation plan…';

  @override
  String get chatReadRole => 'Reading character profiles';

  @override
  String get chatReadContext => 'Reading creation context';

  @override
  String get chatTopics => 'Writing story ideas';

  @override
  String get chatPrepareRole => 'Preparing character creation';

  @override
  String get redemptionCenter => 'Invite Friends';

  @override
  String get redemptionPageTitle => 'Invite Friends';

  @override
  String get redemptionMyCodes => 'My Invite Codes';

  @override
  String get redemptionRegistrationReward => 'Welcome Reward';

  @override
  String get redemptionInviteTitle => 'Invite friends, earn points';

  @override
  String get redemptionInviteDescription =>
      'Earn 200 points for each friend\nwho registers and signs in.';

  @override
  String get redemptionRewardTitle => 'A welcome gift from a friend';

  @override
  String redemptionRewardDescription(int points) {
    return 'Enter a friend\'s invite code\nto receive $points points.';
  }

  @override
  String get redemptionPoints => 'points';

  @override
  String get redemptionFriendCode => 'Friend\'s Invite Code';

  @override
  String get redemptionFriendPlaceholder => 'Enter invite code (once per user)';

  @override
  String get redemptionClaimed => 'Claimed';

  @override
  String get redemptionPending => 'Unused';

  @override
  String get redemptionUsed => 'Used by a friend';

  @override
  String get redemptionRecords => 'Invitation History';

  @override
  String get redemptionRegistered => 'Registered';

  @override
  String get redemptionCodesEmpty => 'No invite codes yet';

  @override
  String get redemptionRecordsEmpty => 'No invitations yet';

  @override
  String get redemptionFooter =>
      'Rewards follow the activity rules. Updates may be delayed.';

  @override
  String get redemptionLoadFailed => 'Could not load. Please retry.';

  @override
  String get redemptionRewardClosed =>
      'Welcome rewards are currently unavailable';

  @override
  String get redemptionClaimSuccess => 'Welcome reward claimed';

  @override
  String get redemptionFailed => 'Could not redeem. Please try again later.';

  @override
  String get redemptionCopied => 'Invite code copied';

  @override
  String get redemptionLoadMore => 'Load more';

  @override
  String get redemptionLoginRequired => 'Sign in to invite friends';

  @override
  String get redemptionBindRequired => 'Link WeChat to view invite codes';

  @override
  String get redemptionBindAction => 'Link WeChat';

  @override
  String get redemptionBindDescription =>
      'Scan with WeChat to link your account';

  @override
  String get redemptionQrExpired => 'QR code expired. Please refresh.';

  @override
  String get redemptionQrFailed => 'Could not load QR code';

  @override
  String get redemptionBindingSuccess => 'WeChat linked';

  @override
  String get redemptionBindingCheck => 'Check link status';

  @override
  String get redemptionBindingWaiting => 'Waiting for WeChat scan';

  @override
  String get teachingAll => 'All';

  @override
  String get teachingCatalog => 'Contents';

  @override
  String get teachingRequiredMember => 'membership';

  @override
  String get teachingDocumentEmpty => 'This course has no content yet';

  @override
  String get teachingDocumentFailed =>
      'Could not load the course content. Please try again';

  @override
  String get teachingReaderUnavailable =>
      'Course reading is unavailable on this platform';

  @override
  String get teachingCreatorTitle => 'Creator center';

  @override
  String get teachingCreatorDescription =>
      'A learning platform\nfor new AI creators';

  @override
  String get teachingCommunityTitle => 'Community';

  @override
  String get teachingCommunityDescription =>
      'Meet other creators\nScan to join POPi';

  @override
  String get teachingCommunityUnavailable => 'Community QR code unavailable';

  @override
  String get teachingMemberTitle => 'Member offers';

  @override
  String get teachingMemberDescription =>
      'Unlock premium courses\nExplore more ways to create';

  @override
  String teachingMemberPrice(String price) {
    return 'From ¥$price\nUnlock premium courses';
  }

  @override
  String teachingInstructor(String name) {
    return 'Tutor: $name';
  }

  @override
  String get teachingFree => 'Free';

  @override
  String get teachingUntitled => 'Untitled course';

  @override
  String get teachingLoading => 'Loading courses';

  @override
  String get teachingEmpty => 'No courses available';

  @override
  String get teachingLoadFailed => 'Unable to load courses. Try again later';

  @override
  String get teachingLoadMoreFailed => 'Unable to load more. Tap to retry';

  @override
  String get teachingCategoriesFailed =>
      'Unable to load categories. Tap to retry';

  @override
  String get sessionArtifactsTitle => 'Conversation Outputs';

  @override
  String get sessionArtifactAll => 'All';

  @override
  String get sessionArtifactRoles => 'Roles';

  @override
  String get sessionArtifactScripts => 'Text';

  @override
  String get sessionArtifactVideos => 'Videos';

  @override
  String get sessionArtifactAudioDetail => 'Audio Details';

  @override
  String get sessionArtifactImageDetail => 'Image Details';

  @override
  String get sessionArtifactScriptDetail => 'Script Details';

  @override
  String get sessionArtifactVideoDetail => 'Video Details';

  @override
  String get sessionArtifactsEmpty => 'No outputs yet';

  @override
  String get chatAskUser => 'Preparing questions';

  @override
  String get chatSaveRole => 'Saving character profile';

  @override
  String get chatPublishRole => 'Preparing character publication';

  @override
  String get chatPreviewImage => 'Preview image';

  @override
  String get chatCollapseProfile => 'Collapse profile';

  @override
  String get chatConfirmGeneration => 'Generate';

  @override
  String get generationCreditNotice =>
      'Please note: Clicking \"Generate\" will deduct the corresponding points. Points already consumed are non-refundable. Please carefully review your materials, prompts, and generation settings before submitting.';

  @override
  String get generationCreditNoticeNonRefundable =>
      'Points already consumed are non-refundable';

  @override
  String get chatRoleName => 'Name';

  @override
  String get chatReconnecting => 'Connection lost. Reconnecting…';

  @override
  String get chatRequestFailed => 'Request failed. Please try again';

  @override
  String get chatInsufficientPoints =>
      'Not enough points. Top up and try again';

  @override
  String get chatRunFailed => 'This request failed';

  @override
  String get chatStopped => 'Stopped';

  @override
  String get chatCompleted => 'Completed';

  @override
  String get chatTextTopic => 'Story idea';

  @override
  String get chatTextScript => 'Script';

  @override
  String get chatTextStoryboard => 'Storyboard prompt';

  @override
  String get chatTextUnknownDuration => 'Duration not recorded';

  @override
  String get chatProgressDetails => 'Progress';

  @override
  String get chatProgressPending => 'Pending';

  @override
  String get chatProgressRunning => 'In progress';

  @override
  String get chatProgressWaiting => 'Waiting';

  @override
  String get chatProgressFailed => 'Failed';

  @override
  String get chatProgressCompleted => 'Done';

  @override
  String get chatProgressRunFailed => 'Failed';

  @override
  String get chatProgressStopped => 'Reply stopped';

  @override
  String get chatProgressPrepare => 'Preparing context';

  @override
  String get chatProgressReply => 'Composing reply';

  @override
  String get chatProgressSaveText => 'Saving written content';

  @override
  String get chatProgressPreparePlan => 'Preparing generation plan';

  @override
  String get chatProgressUpdateRole => 'Updating character';

  @override
  String get chatProgressProcessing => 'Processing…';

  @override
  String get chatProgressUnderstanding => 'Understanding your request…';

  @override
  String get chatProgressSelectingSkill => 'Selecting a creative skill…';

  @override
  String get chatProgressReadingRules => 'Reading creative guidelines…';

  @override
  String get chatProgressComposing => 'Planning the response…';

  @override
  String get chatProgressPreparingGeneration =>
      'Preparing the generation task…';

  @override
  String get chatProgressGeneratingArtifact => 'Generating content…';

  @override
  String get chatProgressCompletingDelivery =>
      'Output generated. Finishing delivery…';

  @override
  String get chatProgressWaitingInput => 'Waiting for your input…';

  @override
  String get chatProgressAnalyze => 'Analyzing your request';

  @override
  String get chatProgressExecuteTool => 'Performing operation';

  @override
  String get chatProgressLoadSkill => 'Loading creative guidance';

  @override
  String get chatProgressSkillTopics => 'Loading story guidance';

  @override
  String get chatProgressSkillScript => 'Loading script guidance';

  @override
  String get chatProgressSkillStoryboard => 'Loading storyboard guidance';

  @override
  String get chatProgressSkillThreeView => 'Loading character sheet guidance';

  @override
  String get chatProgressWriteScript => 'Writing script';

  @override
  String get chatProgressWriteStoryboard =>
      'Writing storyboard and video prompt';

  @override
  String get chatProgressReadTextSources =>
      'Reading source text and requirements';

  @override
  String get chatProgressValidateText =>
      'Checking content, duration and structure';

  @override
  String get chatProgressReadText => 'Reading written content';

  @override
  String get chatProgressSearchRoles => 'Finding characters';

  @override
  String get chatProgressCreateRole => 'Creating character';

  @override
  String get chatProgressCopyRole => 'Preparing personal character copy';

  @override
  String get chatProgressAdoptRoleImage => 'Saving selected character image';

  @override
  String get chatProgressReadAccount => 'Reading account profile';

  @override
  String get chatProgressSearchAccounts => 'Finding accounts';

  @override
  String get chatProgressSelectAccount => 'Loading selected account';

  @override
  String get chatProgressUpdateAccount => 'Updating account preferences';

  @override
  String get chatProgressUpdateMemory => 'Updating account memory';

  @override
  String get chatProgressSearchCreations => 'Finding previous creations';

  @override
  String get chatProgressReadCreation => 'Reading previous creation';

  @override
  String get chatProgressReadTemplates => 'Reading style templates';

  @override
  String get chatProgressReadReferences => 'Preparing references';

  @override
  String get chatProgressValidatePlan =>
      'Checking model capabilities and parameters';

  @override
  String get chatProgressEstimate => 'Estimating credits';

  @override
  String get chatProgressVerifyResult => 'Verifying operation result';

  @override
  String get chatProgressCompilePrompt => 'Writing image prompt';

  @override
  String get chatProgressValidatePrompt => 'Checking image prompt';

  @override
  String get chatProgressSavePrompt => 'Saving image prompt';

  @override
  String get chatProgressRetryPrompt =>
      'Prompt compilation interrupted; awaiting retry';

  @override
  String get chatProgressSubmitGeneration => 'Submitting generation task';

  @override
  String get chatProgressQueuedGeneration => 'Queued for generation';

  @override
  String get chatProgressGenerateImage => 'Generating image';

  @override
  String get chatProgressGenerateVideo => 'Generating video';

  @override
  String get chatProgressGenerateAudio => 'Generating audio';

  @override
  String get chatProgressSaveMedia => 'Saving generated result';

  @override
  String get chatProgressSyncResult => 'Retrying result synchronization';

  @override
  String get chatExpired => 'Expired';

  @override
  String get chatAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get chatStop => 'Stop reply';

  @override
  String get chatSending => 'Sending';

  @override
  String get chatPlayVideo => 'Play video';

  @override
  String get chatPlayAudio => 'Play audio';

  @override
  String get chatCustomAnswer => 'Add your own answer';

  @override
  String get chatMediaPrompt => 'Please use these images as references';

  @override
  String get chatHistoryLoadFailed => 'Unable to load conversations';

  @override
  String chatEstimatedPoints(String points) {
    return 'Estimated cost: $points points';
  }

  @override
  String get demoConversations => 'Conversations';

  @override
  String get demoAssets => 'Assets';

  @override
  String get demoSearchHistory => 'Search conversations';

  @override
  String get demoSearchAssets => 'Search assets';

  @override
  String get demoProject => 'Project';

  @override
  String get demoConversation => 'Chat';

  @override
  String get demoWorkflow => 'Workflow';

  @override
  String get demoNew => 'New conversation';

  @override
  String get demoSettings => 'Conversation settings';

  @override
  String get demoInfo => 'Info';

  @override
  String get demoCapabilities => 'Skills';

  @override
  String get demoOutputs => 'Outputs';

  @override
  String get demoLinkedRoles => 'Linked characters';

  @override
  String get demoAddMembers => 'Add members';

  @override
  String get demoMemberProfile => 'Assistant profile';

  @override
  String get demoRoleProfile => 'Character profile';

  @override
  String get demoPopi => 'POPi';

  @override
  String get demoDesigner => 'Character designer';

  @override
  String get demoWriter => 'Script writer';

  @override
  String get demoDirector => 'Film director';

  @override
  String get demoSound => 'Sound creator';

  @override
  String get demoPopiDescription =>
      'A creative assistant for images, stories and video';

  @override
  String get demoDesignerDescription => 'Create characters and scene images';

  @override
  String get demoWriterDescription => 'Turn ideas into scripts and storyboards';

  @override
  String get demoDirectorDescription =>
      'Create moving images and finished videos';

  @override
  String get demoSoundDescription => 'Create voices, music and sound effects';

  @override
  String get demoRename => 'Rename conversation';

  @override
  String get demoName => 'Name';

  @override
  String get demoPreferences => 'Account preferences';

  @override
  String get demoDirection => 'Content direction';

  @override
  String get demoFeeling => 'Audience feeling';

  @override
  String get demoFeelingValue => 'Authentic, with a little tenderness';

  @override
  String get demoFormat => 'Format';

  @override
  String get demoFormatValue => 'AI realism × short stories';

  @override
  String get demoAudience => 'Audience';

  @override
  String get demoAudienceValue => 'Students and working professionals';

  @override
  String get demoPositioning => 'Account positioning';

  @override
  String get demoCharacterSkill => 'Character settings';

  @override
  String get demoScriptSkill => 'Scripts and storyboards';

  @override
  String get demoImageSkill => 'Image generation';

  @override
  String get demoVideoSkill => 'Video generation';

  @override
  String get demoAudioSkill => 'Audio generation';

  @override
  String get demoEnabledHere => 'Enabled in this conversation';

  @override
  String get demoWorkMode => 'Working mode';

  @override
  String get demoOnDemand => 'On demand';

  @override
  String get demoOfficialRoles => 'Official';

  @override
  String get demoMyRoles => 'My characters';

  @override
  String get demoCreateRole => 'Create character';

  @override
  String get demoJoin => 'Join creation';

  @override
  String get demoNoRoles => 'No linked characters';

  @override
  String get demoNoResults => 'No matching results';

  @override
  String get demoEmptyAssets => 'No assets yet';

  @override
  String get demoEmptyConversations => 'No conversations yet';

  @override
  String get demoAll => 'All';

  @override
  String get demoImages => 'Images';

  @override
  String get demoVideos => 'Videos';

  @override
  String get demoScripts => 'Scripts';

  @override
  String get demoAudio => 'Audio';

  @override
  String get demoUpload => 'Upload material';

  @override
  String get demoSampleLibrary => 'Material library';

  @override
  String get demoImport => 'Import';

  @override
  String get demoImported => 'Material added to your library';

  @override
  String get demoAssetDetails => 'Asset details';

  @override
  String get demoRenameAsset => 'Rename asset';

  @override
  String get demoAudioDetails => 'Audio details';

  @override
  String get demoAudioBackward => 'Back 15 seconds';

  @override
  String get demoAudioForward => 'Forward 15 seconds';

  @override
  String get demoGenerated => 'Completed';

  @override
  String get demoComposer => 'Say something to POPi…';

  @override
  String get demoGreeting => 'Hi there';

  @override
  String get demoGreetingDetail => 'What would you like to create?';

  @override
  String get demoDisclaimer => 'AI-generated results may contain errors';

  @override
  String get demoThinking => 'POPi is thinking…';

  @override
  String get demoVoice => 'Let Alice meet an old friend at a cafe.';

  @override
  String get demoQuickImage => 'Generate five scene images';

  @override
  String get demoQuickScript => 'Write a reunion script';

  @override
  String get demoQuickVideo => 'Create a weekend video';

  @override
  String get demoQuickAudio => 'Create afternoon music';

  @override
  String get demoReply =>
      'This could become a warm short film.\\n\\n**Three ideas**\\n1. An unexpected reunion at a cafe\\n2. Walking home before graduation\\n3. A letter that arrived years late\\n\\nWhich shall we develop?';

  @override
  String get demoImageReply =>
      'Your scene images are ready. How do you like this look?';

  @override
  String get demoScriptReply => 'Your script and storyboard are ready.';

  @override
  String get demoAudioReply => 'Your afternoon music is ready.';

  @override
  String get demoVideoReply => 'Your weekend video is ready.';

  @override
  String get demoWelcomeTitle => 'Hi, creator';

  @override
  String get demoWelcomeCopy =>
      'Before we begin,\ntell me what you\nwould like to create.';

  @override
  String get demoStartIp => 'Create a new IP account';

  @override
  String get demoStartRole => 'Start with a character';

  @override
  String get demoStartIdea => 'Start with an idea';

  @override
  String get demoStartChat => 'Let\'s chat first';

  @override
  String get demoReset => 'Reset demo data';

  @override
  String get demoResetDescription =>
      'Restore the original conversations and assets and clear your demo edits?';

  @override
  String get demoResetDone => 'Demo data restored';

  @override
  String get demoStorageError => 'Could not save locally. Please try again.';

  @override
  String get demoDeleteDescription => 'Delete this item?';

  @override
  String get demoUpdated => 'Saved';

  @override
  String get demoNow => 'Just now';

  @override
  String get demoPlayback => 'Play';

  @override
  String get demoPause => 'Pause';

  @override
  String get demoSeek => 'Playback position';

  @override
  String get demoReplay => 'Replay';

  @override
  String get demoReference => 'Image / Reference';

  @override
  String get demoImageMeta => 'Image / 9:16';

  @override
  String get demoScriptMeta => 'Script/MD';

  @override
  String get demoAudioMeta => 'Audio/00:24';

  @override
  String get demoVideoMeta => 'Video / 00:08';

  @override
  String get demoAttachments => 'Add material';

  @override
  String get demoRemoveAttachment => 'Remove material';

  @override
  String get demoChoose => 'Select members';

  @override
  String get demoProfile => 'Profile';

  @override
  String get demoMembers => 'Members';

  @override
  String get demoRoleBio =>
      'Loves life and turns everyday moments into warm stories.';

  @override
  String get demoAddSkill => 'Add a skill';

  @override
  String get demoGenerating => 'Creating';

  @override
  String get demoNewRoleName => 'Character name';

  @override
  String get demoSend => 'Send';

  @override
  String get demoSessionName => 'Conversation name';

  @override
  String demoRoleCount(int count) {
    return '$count characters';
  }

  @override
  String demoSelectedCount(int count, int total) {
    return 'Selected $count/$total';
  }

  @override
  String get demoSelectMembers => 'Select members';

  @override
  String get demoEditMember => 'Edit member';

  @override
  String get demoMyName => 'My name';

  @override
  String get demoMyAppearance => 'My appearance';

  @override
  String get demoRandomAppearance => 'Suggest another';

  @override
  String demoAvatarNumber(int number) {
    return 'Avatar $number';
  }

  @override
  String get demoBackgroundColor => 'Background color';

  @override
  String get demoProfileLink => 'Profile';

  @override
  String get demoEnabledItems => 'Enabled skills';

  @override
  String get demoCharacterDetail => 'Keep the character identity and look';

  @override
  String get demoScriptDetail => 'Turn ideas into a complete plan';

  @override
  String get demoImageDetail => 'Create character and scene images';

  @override
  String get demoVideoDetail => 'Create videos ready to publish';

  @override
  String get demoAudioDetail => 'Create voices, music and sound effects';

  @override
  String get demoUploadLibrary => 'Upload to asset library';

  @override
  String get demoSelectFiles => 'Select files';

  @override
  String get demoFileTypes => 'Images, videos, scripts, audio';

  @override
  String demoSelectedFiles(int count) {
    return '$count files selected';
  }
}
