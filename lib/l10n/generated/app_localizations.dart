import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'POPi'**
  String get appTitle;

  /// No description provided for @roleGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with characters'**
  String get roleGuideTitle;

  /// No description provided for @roleGuideDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 5 characters\nto start a project conversation'**
  String get roleGuideDescription;

  /// No description provided for @roleCastTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your cast'**
  String get roleCastTitle;

  /// No description provided for @roleCastDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 3 characters\nfrom your project for the video:'**
  String get roleCastDescription;

  /// No description provided for @roleTopicTitle.
  ///
  /// In en, this message translates to:
  /// **'Find their next story'**
  String get roleTopicTitle;

  /// No description provided for @roleTopicDescription.
  ///
  /// In en, this message translates to:
  /// **'POPi suggests 3 stories\nfor your characters:'**
  String get roleTopicDescription;

  /// No description provided for @roleProductionTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your video'**
  String get roleProductionTitle;

  /// No description provided for @roleProductionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a model and settings\nto bring your story to life:'**
  String get roleProductionDescription;

  /// No description provided for @roleCreateProject.
  ///
  /// In en, this message translates to:
  /// **'Create project'**
  String get roleCreateProject;

  /// No description provided for @roleGuideViewMore.
  ///
  /// In en, this message translates to:
  /// **'View more'**
  String get roleGuideViewMore;

  /// No description provided for @roleSelectedCount.
  ///
  /// In en, this message translates to:
  /// **' ({count} selected)'**
  String roleSelectedCount(int count);

  /// No description provided for @roleChooseCast.
  ///
  /// In en, this message translates to:
  /// **'Use this cast'**
  String get roleChooseCast;

  /// No description provided for @roleSelectProjectFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose characters for your project first'**
  String get roleSelectProjectFirst;

  /// No description provided for @roleSelectCastFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose your cast first'**
  String get roleSelectCastFirst;

  /// No description provided for @roleProjectLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 5 project characters'**
  String get roleProjectLimit;

  /// No description provided for @roleCastLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 3 cast members'**
  String get roleCastLimit;

  /// No description provided for @roleProjectName.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s project'**
  String roleProjectName(String name);

  /// No description provided for @roleProjectCount.
  ///
  /// In en, this message translates to:
  /// **'{count} project characters'**
  String roleProjectCount(int count);

  /// No description provided for @roleCastCount.
  ///
  /// In en, this message translates to:
  /// **'{count} cast members'**
  String roleCastCount(int count);

  /// No description provided for @roleChooseStory.
  ///
  /// In en, this message translates to:
  /// **'Choose this story'**
  String get roleChooseStory;

  /// No description provided for @roleRefreshStories.
  ///
  /// In en, this message translates to:
  /// **'Try another set'**
  String get roleRefreshStories;

  /// No description provided for @rolePreviousStory.
  ///
  /// In en, this message translates to:
  /// **'Previous story'**
  String get rolePreviousStory;

  /// No description provided for @roleNextStory.
  ///
  /// In en, this message translates to:
  /// **'Next story'**
  String get roleNextStory;

  /// No description provided for @roleStoryOverview.
  ///
  /// In en, this message translates to:
  /// **'Story overview'**
  String get roleStoryOverview;

  /// No description provided for @roleSwitchProject.
  ///
  /// In en, this message translates to:
  /// **'Switch project'**
  String get roleSwitchProject;

  /// No description provided for @roleMyProjects.
  ///
  /// In en, this message translates to:
  /// **'My IP projects'**
  String get roleMyProjects;

  /// No description provided for @roleEditProjectRoles.
  ///
  /// In en, this message translates to:
  /// **'Edit project characters'**
  String get roleEditProjectRoles;

  /// No description provided for @roleViewProfiles.
  ///
  /// In en, this message translates to:
  /// **'View character profiles'**
  String get roleViewProfiles;

  /// No description provided for @roleProfilePage.
  ///
  /// In en, this message translates to:
  /// **'Character profile {index}/{total}'**
  String roleProfilePage(int index, int total);

  /// No description provided for @roleFullProfile.
  ///
  /// In en, this message translates to:
  /// **'View full character profile'**
  String get roleFullProfile;

  /// No description provided for @rolePreviousProfile.
  ///
  /// In en, this message translates to:
  /// **'Previous character profile'**
  String get rolePreviousProfile;

  /// No description provided for @roleNextProfile.
  ///
  /// In en, this message translates to:
  /// **'Next character profile'**
  String get roleNextProfile;

  /// No description provided for @roleDetailedStory.
  ///
  /// In en, this message translates to:
  /// **'Full story'**
  String get roleDetailedStory;

  /// No description provided for @roleStoryDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Plot development'**
  String get roleStoryDevelopment;

  /// No description provided for @roleStoryContent.
  ///
  /// In en, this message translates to:
  /// **'Main content'**
  String get roleStoryContent;

  /// No description provided for @roleProduceVideo.
  ///
  /// In en, this message translates to:
  /// **'Create video'**
  String get roleProduceVideo;

  /// No description provided for @roleViewPlan.
  ///
  /// In en, this message translates to:
  /// **'View plan'**
  String get roleViewPlan;

  /// No description provided for @roleGeneratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating your video...'**
  String get roleGeneratingTitle;

  /// No description provided for @roleGeneratingDescription.
  ///
  /// In en, this message translates to:
  /// **'Stay here to wait\nor view the plan in chat'**
  String get roleGeneratingDescription;

  /// No description provided for @roleGeneratedTitle.
  ///
  /// In en, this message translates to:
  /// **'Creation complete!'**
  String get roleGeneratedTitle;

  /// No description provided for @roleGeneratedDescription.
  ///
  /// In en, this message translates to:
  /// **'Refine it in chat\nor explore a new idea with Agent'**
  String get roleGeneratedDescription;

  /// No description provided for @roleGenerationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Creation interrupted'**
  String get roleGenerationFailedTitle;

  /// No description provided for @roleGenerationFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your plan is saved\nRetry or adjust it to continue'**
  String get roleGenerationFailedDescription;

  /// No description provided for @roleGenerationCanceledTitle.
  ///
  /// In en, this message translates to:
  /// **'Production stopped'**
  String get roleGenerationCanceledTitle;

  /// No description provided for @roleGenerationCanceledDescription.
  ///
  /// In en, this message translates to:
  /// **'Your plan is saved\nAdjust it and start again'**
  String get roleGenerationCanceledDescription;

  /// No description provided for @roleTaskRunning.
  ///
  /// In en, this message translates to:
  /// **'Creating your video...'**
  String get roleTaskRunning;

  /// No description provided for @roleTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get roleTaskCompleted;

  /// No description provided for @roleTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'Creation failed. Try again.'**
  String get roleTaskFailed;

  /// No description provided for @roleTaskCanceled.
  ///
  /// In en, this message translates to:
  /// **'Task stopped'**
  String get roleTaskCanceled;

  /// No description provided for @roleTaskExecuting.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get roleTaskExecuting;

  /// No description provided for @roleStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get roleStatusCompleted;

  /// No description provided for @roleStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get roleStatusFailed;

  /// No description provided for @roleStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get roleStatusCanceled;

  /// No description provided for @roleStageCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get roleStageCharacters;

  /// No description provided for @roleStageScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get roleStageScript;

  /// No description provided for @roleStageStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Storyboard'**
  String get roleStageStoryboard;

  /// No description provided for @roleStageVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get roleStageVideo;

  /// No description provided for @roleStageReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get roleStageReview;

  /// No description provided for @roleWorkGenerating.
  ///
  /// In en, this message translates to:
  /// **'Creating your video...'**
  String get roleWorkGenerating;

  /// No description provided for @roleStopProduction.
  ///
  /// In en, this message translates to:
  /// **'Stop production'**
  String get roleStopProduction;

  /// No description provided for @roleStopProductionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this production?'**
  String get roleStopProductionTitle;

  /// No description provided for @roleStopProductionDescription.
  ///
  /// In en, this message translates to:
  /// **'Your characters, story and model settings will be kept so you can start again.'**
  String get roleStopProductionDescription;

  /// No description provided for @roleKeepGenerating.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get roleKeepGenerating;

  /// No description provided for @roleContinueCreating.
  ///
  /// In en, this message translates to:
  /// **'Continue creating'**
  String get roleContinueCreating;

  /// No description provided for @roleChatInSession.
  ///
  /// In en, this message translates to:
  /// **'Chat with Agent'**
  String get roleChatInSession;

  /// No description provided for @roleProjectSession.
  ///
  /// In en, this message translates to:
  /// **'Project conversation'**
  String get roleProjectSession;

  /// No description provided for @roleScriptContent.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get roleScriptContent;

  /// No description provided for @roleStoryboardContent.
  ///
  /// In en, this message translates to:
  /// **'Storyboard'**
  String get roleStoryboardContent;

  /// No description provided for @rolePreviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Interaction preview · No points charged'**
  String get rolePreviewNotice;

  /// No description provided for @rolePreviewCover.
  ///
  /// In en, this message translates to:
  /// **'Example cover'**
  String get rolePreviewCover;

  /// No description provided for @roleEstimatePending.
  ///
  /// In en, this message translates to:
  /// **'Choose a model and settings to see a points estimate'**
  String get roleEstimatePending;

  /// No description provided for @roleEstimatePreview.
  ///
  /// In en, this message translates to:
  /// **'The final quote applies when production is connected'**
  String get roleEstimatePreview;

  /// No description provided for @roleStoryPosition.
  ///
  /// In en, this message translates to:
  /// **'{index}/{total}'**
  String roleStoryPosition(int index, int total);

  /// No description provided for @roleExampleDevelopment1.
  ///
  /// In en, this message translates to:
  /// **'An unwritten graduation plan leads to a friend\'s sketchbook and a decision to make a short film. Revisiting those memories helps the character find a passion.'**
  String get roleExampleDevelopment1;

  /// No description provided for @roleExampleDevelopment2.
  ///
  /// In en, this message translates to:
  /// **'A roommate\'s strange behavior prompts a secret investigation. A series of comic misunderstandings ends with a surprise farewell party in their classroom.'**
  String get roleExampleDevelopment2;

  /// No description provided for @roleExampleDevelopment3.
  ///
  /// In en, this message translates to:
  /// **'A setback breaks through her usual brave face. Her friends support her in small everyday ways until she feels ready to share how tired she is.'**
  String get roleExampleDevelopment3;

  /// No description provided for @roleExampleDevelopment4.
  ///
  /// In en, this message translates to:
  /// **'Dinner-table jokes give way to attentive listening. She shares her dream, the others share theirs, and they make a promise to meet again in a year.'**
  String get roleExampleDevelopment4;

  /// No description provided for @roleExampleDevelopment5.
  ///
  /// In en, this message translates to:
  /// **'A misunderstanding pulls two friends apart and well-meant interventions make it worse. A rainy-day encounter over hot cocoa finally gives them space to talk.'**
  String get roleExampleDevelopment5;

  /// No description provided for @roleExampleDevelopment6.
  ///
  /// In en, this message translates to:
  /// **'Watching a sunrise is the last wish before moving away. Small mishaps bring the friends closer, and their goodbye becomes a promise to meet again.'**
  String get roleExampleDevelopment6;

  /// No description provided for @roleExampleContent1.
  ///
  /// In en, this message translates to:
  /// **'Shot 1: A pen hovers over a blank graduation plan beside the window.\nShot 2: Sketchbook photographs alternate with campus memories.\nShot 3: The friends raise a camera and film their first scene at sunset.'**
  String get roleExampleContent1;

  /// No description provided for @roleExampleContent2.
  ///
  /// In en, this message translates to:
  /// **'Shot 1: The roommate slips out as friends peek around the door.\nShot 2: Their clumsy investigation takes them across campus.\nShot 3: A classroom door opens onto photographs and party lights.'**
  String get roleExampleContent2;

  /// No description provided for @roleExampleContent3.
  ///
  /// In en, this message translates to:
  /// **'Shot 1: She sits at a desk and lets her forced smile fade.\nShot 2: Breakfast, patient waiting and notes show her friends\' care.\nShot 3: Surrounded by friends, she rests her head on a shoulder.'**
  String get roleExampleContent3;

  /// No description provided for @roleExampleContent4.
  ///
  /// In en, this message translates to:
  /// **'Shot 1: Dinner-table laughter settles as everyone listens.\nShot 2: Each friend writes a dream on a slip of paper.\nShot 3: They seal the notes in a box dated one year from today.'**
  String get roleExampleContent4;

  /// No description provided for @roleExampleContent5.
  ///
  /// In en, this message translates to:
  /// **'Shot 1: Two friends pass silently in a hallway.\nShot 2: Rain falls outside a cafe while cocoa steams on the table.\nShot 3: After an honest conversation, they leave under one umbrella.'**
  String get roleExampleContent5;

  /// No description provided for @roleExampleContent6.
  ///
  /// In en, this message translates to:
  /// **'Shot 1: A wish list has one unchecked item: watch a sunrise.\nShot 2: Forgotten keys and wrong turns turn into shared laughter.\nShot 3: They stand together in morning light and promise to reunite.'**
  String get roleExampleContent6;

  /// No description provided for @roleModelParameters.
  ///
  /// In en, this message translates to:
  /// **'Model / settings'**
  String get roleModelParameters;

  /// No description provided for @roleModelPending.
  ///
  /// In en, this message translates to:
  /// **'Model / settings (choose)'**
  String get roleModelPending;

  /// No description provided for @roleChooseParametersFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a model and settings first'**
  String get roleChooseParametersFirst;

  /// No description provided for @roleVideoPreference.
  ///
  /// In en, this message translates to:
  /// **'Video preferences'**
  String get roleVideoPreference;

  /// No description provided for @roleImagePreference.
  ///
  /// In en, this message translates to:
  /// **'Image preferences'**
  String get roleImagePreference;

  /// No description provided for @roleModelSelection.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get roleModelSelection;

  /// No description provided for @roleResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get roleResolution;

  /// No description provided for @roleRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get roleRatio;

  /// No description provided for @roleDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get roleDimensions;

  /// No description provided for @roleQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get roleQuantity;

  /// No description provided for @roleEstimatedPoints.
  ///
  /// In en, this message translates to:
  /// **'Estimated points: {points}'**
  String roleEstimatedPoints(int points);

  /// No description provided for @roleModelSoraDescription.
  ///
  /// In en, this message translates to:
  /// **'OpenAI media generation with synchronized audio and video'**
  String get roleModelSoraDescription;

  /// No description provided for @roleModelVeoDescription.
  ///
  /// In en, this message translates to:
  /// **'Google video model with cinematic quality and precise camera control'**
  String get roleModelVeoDescription;

  /// No description provided for @roleModelJimengDescription.
  ///
  /// In en, this message translates to:
  /// **'ByteDance video model with consistent motion and image-to-video generation'**
  String get roleModelJimengDescription;

  /// No description provided for @roleModelKlingDescription.
  ///
  /// In en, this message translates to:
  /// **'Kuaishou video model with natural physics and stable camera movement'**
  String get roleModelKlingDescription;

  /// No description provided for @roleModelViduDescription.
  ///
  /// In en, this message translates to:
  /// **'ShengShu model with reference-based effects and material transfer'**
  String get roleModelViduDescription;

  /// No description provided for @roleModelDiscount.
  ///
  /// In en, this message translates to:
  /// **'50% off'**
  String get roleModelDiscount;

  /// No description provided for @roleVideoPlanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create a video using this plan.\nProject: {project}\nProject characters: {roles}\nCast: {cast}\nTopic: {title}\nStory overview: {story}\nVideo model: {model}\nVideo settings: {video}\nImage settings: {image}\nQuantity: {quantity}'**
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
  );

  /// No description provided for @roleExampleAlice.
  ///
  /// In en, this message translates to:
  /// **'Alice'**
  String get roleExampleAlice;

  /// No description provided for @roleExampleErer.
  ///
  /// In en, this message translates to:
  /// **'Erer'**
  String get roleExampleErer;

  /// No description provided for @roleExampleHua.
  ///
  /// In en, this message translates to:
  /// **'Hua Xileng'**
  String get roleExampleHua;

  /// No description provided for @roleExampleDoudou.
  ///
  /// In en, this message translates to:
  /// **'Doudou'**
  String get roleExampleDoudou;

  /// No description provided for @roleExampleConfused.
  ///
  /// In en, this message translates to:
  /// **'Little Dreamer'**
  String get roleExampleConfused;

  /// No description provided for @roleExampleStrawberry.
  ///
  /// In en, this message translates to:
  /// **'Strawberry'**
  String get roleExampleStrawberry;

  /// No description provided for @roleExampleQiqi.
  ///
  /// In en, this message translates to:
  /// **'Qiqi and Didi'**
  String get roleExampleQiqi;

  /// No description provided for @roleExampleMermaid.
  ///
  /// In en, this message translates to:
  /// **'Miss Mermaid'**
  String get roleExampleMermaid;

  /// No description provided for @roleExampleDescription.
  ///
  /// In en, this message translates to:
  /// **'A classmate, roommate, and witty best friend...'**
  String get roleExampleDescription;

  /// No description provided for @roleExampleStoryTitle1.
  ///
  /// In en, this message translates to:
  /// **'After graduation, I found my passion...'**
  String get roleExampleStoryTitle1;

  /// No description provided for @roleExampleStoryTitle2.
  ///
  /// In en, this message translates to:
  /// **'My roommate\'s secret plan'**
  String get roleExampleStoryTitle2;

  /// No description provided for @roleExampleStoryTitle3.
  ///
  /// In en, this message translates to:
  /// **'Today, I\'ll look after you'**
  String get roleExampleStoryTitle3;

  /// No description provided for @roleExampleStoryTitle4.
  ///
  /// In en, this message translates to:
  /// **'The first time I spoke my mind'**
  String get roleExampleStoryTitle4;

  /// No description provided for @roleExampleStoryTitle5.
  ///
  /// In en, this message translates to:
  /// **'Hot cocoa after a misunderstanding'**
  String get roleExampleStoryTitle5;

  /// No description provided for @roleExampleStoryTitle6.
  ///
  /// In en, this message translates to:
  /// **'One last little adventure together'**
  String get roleExampleStoryTitle6;

  /// No description provided for @roleExampleStory1.
  ///
  /// In en, this message translates to:
  /// **'He looks down at the pen in his hand, unable to write his plans for life after graduation. Laughter outside brings back memories of late nights finishing assignments together. A friend notices his hesitation and hands him a sketchbook filled with everyday moments. He realizes his passion has always been telling stories about the people around him. Together, they decide to shoot one final short film before graduation, turning their unspoken thoughts into a story and leaving their future selves a little courage.'**
  String get roleExampleStory1;

  /// No description provided for @roleExampleStory2.
  ///
  /// In en, this message translates to:
  /// **'Their roommate has been slipping out early and returning late. Worried, the friends decide to follow her, stumbling through one funny misunderstanding after another. Behind the classroom door, they discover a surprise farewell party. Photographs cover the walls, each carrying a thank-you she never quite managed to say aloud.'**
  String get roleExampleStory2;

  /// No description provided for @roleExampleStory3.
  ///
  /// In en, this message translates to:
  /// **'The friend who always takes care of everyone loses her confidence after a setback. Her companions quietly take over the little things: saving breakfast, waiting for her to come home, remembering a small wish. When she realizes she can be cared for too, she finally lets herself stop pretending to be fine.'**
  String get roleExampleStory3;

  /// No description provided for @roleExampleStory4.
  ///
  /// In en, this message translates to:
  /// **'An ordinary dinner turns into a conversation about unspoken dreams. Encouraged by her friends, she finally shares what she really wants to do. Nobody laughs or rushes her. They write down their wishes and promise to open them together a year later, to see where this small act of courage has taken them.'**
  String get roleExampleStory4;

  /// No description provided for @roleExampleStory5.
  ///
  /// In en, this message translates to:
  /// **'A careless remark leaves two best friends barely speaking. Their companions try to help, creating more confusion along the way. On a rainy evening, the two meet at their usual cafe. Over hot cocoa, an honest conversation reveals they were both waiting for the other to speak first.'**
  String get roleExampleStory5;

  /// No description provided for @roleExampleStory6.
  ///
  /// In en, this message translates to:
  /// **'Before moving out, the friends make a list of things to do together. The final wish is to watch a sunrise. Forgotten keys, a wrong turn, and a missed breakfast almost derail the trip. Standing in the morning light, they skip the goodbyes and simply promise another little adventure when they meet again.'**
  String get roleExampleStory6;

  /// No description provided for @officialRoles.
  ///
  /// In en, this message translates to:
  /// **'Official roles'**
  String get officialRoles;

  /// No description provided for @roleDetails.
  ///
  /// In en, this message translates to:
  /// **'Role details'**
  String get roleDetails;

  /// No description provided for @roleArchive.
  ///
  /// In en, this message translates to:
  /// **'Role profile'**
  String get roleArchive;

  /// No description provided for @rolePositioning.
  ///
  /// In en, this message translates to:
  /// **'Character positioning'**
  String get rolePositioning;

  /// No description provided for @roleStyle.
  ///
  /// In en, this message translates to:
  /// **'Personality and expression style'**
  String get roleStyle;

  /// No description provided for @roleAudience.
  ///
  /// In en, this message translates to:
  /// **'Target audience'**
  String get roleAudience;

  /// No description provided for @roleTags.
  ///
  /// In en, this message translates to:
  /// **'Content tags'**
  String get roleTags;

  /// No description provided for @roleBoundaries.
  ///
  /// In en, this message translates to:
  /// **'Expression boundaries'**
  String get roleBoundaries;

  /// No description provided for @roleAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get roleAppearance;

  /// No description provided for @roleFieldPending.
  ///
  /// In en, this message translates to:
  /// **'To be completed'**
  String get roleFieldPending;

  /// No description provided for @roleCertified.
  ///
  /// In en, this message translates to:
  /// **'Certified'**
  String get roleCertified;

  /// No description provided for @roleUncertified.
  ///
  /// In en, this message translates to:
  /// **'Uncertified'**
  String get roleUncertified;

  /// No description provided for @roleProfileReady.
  ///
  /// In en, this message translates to:
  /// **'Profile ready / Keep enriching it'**
  String get roleProfileReady;

  /// No description provided for @roleProfilePending.
  ///
  /// In en, this message translates to:
  /// **'Profile needs more details'**
  String get roleProfilePending;

  /// No description provided for @roleStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Give your character a richer story'**
  String get roleStoryTitle;

  /// No description provided for @roleStoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Talk with the Agent about personality, expression or a new creative direction. Confirm the details for your next topic.'**
  String get roleStoryDescription;

  /// No description provided for @improveRole.
  ///
  /// In en, this message translates to:
  /// **'Enrich role profile'**
  String get improveRole;

  /// No description provided for @confirmRoleChanges.
  ///
  /// In en, this message translates to:
  /// **'Confirm changes'**
  String get confirmRoleChanges;

  /// No description provided for @savingRoleChanges.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingRoleChanges;

  /// No description provided for @roleChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'Role profile saved'**
  String get roleChangesSaved;

  /// No description provided for @roleChangesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the role profile. Try again.'**
  String get roleChangesSaveFailed;

  /// No description provided for @roleFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get roleFieldRequired;

  /// No description provided for @createWithRole.
  ///
  /// In en, this message translates to:
  /// **'Create with this role'**
  String get createWithRole;

  /// No description provided for @deleteRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this role?'**
  String get deleteRoleTitle;

  /// No description provided for @deleteRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'This role will be removed from your personal and community libraries. This cannot be undone.'**
  String get deleteRoleDescription;

  /// No description provided for @roleDeleteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This role cannot be deleted'**
  String get roleDeleteUnavailable;

  /// No description provided for @improveRolePrompt.
  ///
  /// In en, this message translates to:
  /// **'Help enrich the personality, expression and creative direction of {title}.'**
  String improveRolePrompt(String title);

  /// No description provided for @createRolePrompt.
  ///
  /// In en, this message translates to:
  /// **'Recommend creative topics featuring {title}.'**
  String createRolePrompt(String title);

  /// No description provided for @roleDescription.
  ///
  /// In en, this message translates to:
  /// **'About this role'**
  String get roleDescription;

  /// No description provided for @noRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet'**
  String get noRoleDescription;

  /// No description provided for @myRoles.
  ///
  /// In en, this message translates to:
  /// **'My roles'**
  String get myRoles;

  /// No description provided for @noOfficialRoles.
  ///
  /// In en, this message translates to:
  /// **'No official roles yet'**
  String get noOfficialRoles;

  /// No description provided for @noMyRoles.
  ///
  /// In en, this message translates to:
  /// **'No roles of your own yet'**
  String get noMyRoles;

  /// No description provided for @myRolesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create characters to enrich your videos'**
  String get myRolesEmptyDescription;

  /// No description provided for @createNewRole.
  ///
  /// In en, this message translates to:
  /// **'Create a role'**
  String get createNewRole;

  /// No description provided for @createNewRolePrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me create a new character. Let\'s start with positioning, personality and expression style.'**
  String get createNewRolePrompt;

  /// No description provided for @noMoreRoles.
  ///
  /// In en, this message translates to:
  /// **'All roles loaded'**
  String get noMoreRoles;

  /// No description provided for @retryLoadingRoles.
  ///
  /// In en, this message translates to:
  /// **'Could not load roles. Retry'**
  String get retryLoadingRoles;

  /// No description provided for @selectAssets.
  ///
  /// In en, this message translates to:
  /// **'Select assets'**
  String get selectAssets;

  /// No description provided for @assetPreview.
  ///
  /// In en, this message translates to:
  /// **'Image preview'**
  String get assetPreview;

  /// No description provided for @videoCoverPreview.
  ///
  /// In en, this message translates to:
  /// **'Video cover preview'**
  String get videoCoverPreview;

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoPlay;

  /// No description provided for @videoPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoPause;

  /// No description provided for @videoMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get videoMute;

  /// No description provided for @videoUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get videoUnmute;

  /// No description provided for @videoSeek.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get videoSeek;

  /// No description provided for @videoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this video'**
  String get videoLoadFailed;

  /// No description provided for @assetDownloadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No source file is available to download'**
  String get assetDownloadUnavailable;

  /// No description provided for @deleteAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete assets?'**
  String get deleteAssetsTitle;

  /// No description provided for @deleteAssetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected assets? This cannot be undone.'**
  String deleteAssetsDescription(int count);

  /// No description provided for @selectedAssets.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedAssets(int count);

  /// No description provided for @myIpAccounts.
  ///
  /// In en, this message translates to:
  /// **'My IP accounts'**
  String get myIpAccounts;

  /// No description provided for @ipAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'IP Account Management'**
  String get ipAccountsTitle;

  /// No description provided for @loadingIpAccounts.
  ///
  /// In en, this message translates to:
  /// **'Loading accounts'**
  String get loadingIpAccounts;

  /// No description provided for @ipAccountsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ipAccountsAll;

  /// No description provided for @ipAccountsRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently Used'**
  String get ipAccountsRecent;

  /// No description provided for @ipAccountsPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get ipAccountsPaused;

  /// No description provided for @ipAccountNormalStatus.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get ipAccountNormalStatus;

  /// No description provided for @ipAccountPausedStatus.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get ipAccountPausedStatus;

  /// No description provided for @noIpAccounts.
  ///
  /// In en, this message translates to:
  /// **'No IP accounts yet'**
  String get noIpAccounts;

  /// No description provided for @noRecentIpAccounts.
  ///
  /// In en, this message translates to:
  /// **'No recently used accounts'**
  String get noRecentIpAccounts;

  /// No description provided for @noPausedIpAccounts.
  ///
  /// In en, this message translates to:
  /// **'No paused accounts'**
  String get noPausedIpAccounts;

  /// No description provided for @ipAccountDetailsPending.
  ///
  /// In en, this message translates to:
  /// **'Account details are not available yet'**
  String get ipAccountDetailsPending;

  /// No description provided for @ipAccountsPending.
  ///
  /// In en, this message translates to:
  /// **'IP accounts are not available yet'**
  String get ipAccountsPending;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newConversation;

  /// No description provided for @newSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newSessionTitle;

  /// No description provided for @changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get changeAvatar;

  /// No description provided for @avatarSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the image. Try again or check photo permissions.'**
  String get avatarSelectionFailed;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @sheetDemo.
  ///
  /// In en, this message translates to:
  /// **'Sheet Demo'**
  String get sheetDemo;

  /// No description provided for @modalSheet.
  ///
  /// In en, this message translates to:
  /// **'Modal Bottom Sheet'**
  String get modalSheet;

  /// No description provided for @draggableSheet.
  ///
  /// In en, this message translates to:
  /// **'Draggable Sheet'**
  String get draggableSheet;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @uidCopied.
  ///
  /// In en, this message translates to:
  /// **'UID copied'**
  String get uidCopied;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Your new project starts here.'**
  String get welcome;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to POPi'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue creating your own IP'**
  String get loginSubtitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneNumberHint;

  /// No description provided for @passwordLogin.
  ///
  /// In en, this message translates to:
  /// **'Password sign-in'**
  String get passwordLogin;

  /// No description provided for @codeLogin.
  ///
  /// In en, this message translates to:
  /// **'SMS sign-in'**
  String get codeLogin;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password with at least 6 characters'**
  String get invalidPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @graphicalCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Security verification'**
  String get graphicalCaptcha;

  /// No description provided for @captchaSliderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the slider to complete the puzzle'**
  String get captchaSliderHint;

  /// No description provided for @captchaSliderMoving.
  ///
  /// In en, this message translates to:
  /// **'Release to verify'**
  String get captchaSliderMoving;

  /// No description provided for @captchaVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get captchaVerifying;

  /// No description provided for @captchaLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load captcha. Refresh to retry'**
  String get captchaLoadFailed;

  /// No description provided for @captchaVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Try again'**
  String get captchaVerificationFailed;

  /// No description provided for @captchaTooManyErrors.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Refresh to retry'**
  String get captchaTooManyErrors;

  /// No description provided for @graphicalCaptchaHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the characters'**
  String get graphicalCaptchaHint;

  /// No description provided for @refreshCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Refresh image verification'**
  String get refreshCaptcha;

  /// No description provided for @graphicalCaptchaRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the image verification code first'**
  String get graphicalCaptchaRequired;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @verificationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get verificationCodeHint;

  /// No description provided for @sendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendVerificationCode;

  /// No description provided for @sendingVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sendingVerificationCode;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get verificationCodeSent;

  /// No description provided for @resendCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendCountdown(int seconds);

  /// No description provided for @phoneLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone'**
  String get phoneLogin;

  /// No description provided for @loginOrRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Register'**
  String get loginOrRegister;

  /// No description provided for @otherLoginMethods.
  ///
  /// In en, this message translates to:
  /// **'Other sign-in methods'**
  String get otherLoginMethods;

  /// No description provided for @wechatLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with WeChat'**
  String get wechatLogin;

  /// No description provided for @douyinLogin.
  ///
  /// In en, this message translates to:
  /// **'Douyin sign-in'**
  String get douyinLogin;

  /// No description provided for @douyinLoginCanceled.
  ///
  /// In en, this message translates to:
  /// **'Douyin sign-in was canceled'**
  String get douyinLoginCanceled;

  /// No description provided for @douyinLoginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Douyin sign-in is unavailable. Check that Douyin is installed and the app is configured.'**
  String get douyinLoginUnavailable;

  /// No description provided for @douyinLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Douyin sign-in failed. Please try again.'**
  String get douyinLoginFailed;

  /// No description provided for @douyinPhoneBindingRequired.
  ///
  /// In en, this message translates to:
  /// **'Bind your phone number to complete Douyin sign-in.'**
  String get douyinPhoneBindingRequired;

  /// No description provided for @loginAgreement.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree to the User Agreement and Privacy Policy. New phone numbers register automatically.'**
  String get loginAgreement;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get invalidPhoneNumber;

  /// No description provided for @invalidVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit code'**
  String get invalidVerificationCode;

  /// No description provided for @agreementRequired.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the User Agreement and Privacy Policy first'**
  String get agreementRequired;

  /// No description provided for @loginSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get loginSucceeded;

  /// No description provided for @networkRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Network request failed. Try again later'**
  String get networkRequestFailed;

  /// No description provided for @wechatServicePending.
  ///
  /// In en, this message translates to:
  /// **'WeChat authorization is not connected yet'**
  String get wechatServicePending;

  /// No description provided for @wechatLoginCanceled.
  ///
  /// In en, this message translates to:
  /// **'WeChat sign-in was canceled'**
  String get wechatLoginCanceled;

  /// No description provided for @wechatLoginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'WeChat sign-in is unavailable. Check that WeChat is installed and the app is configured.'**
  String get wechatLoginUnavailable;

  /// No description provided for @wechatLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'WeChat sign-in failed. Please try again.'**
  String get wechatLoginFailed;

  /// No description provided for @wechatPhoneBindingRequired.
  ///
  /// In en, this message translates to:
  /// **'Bind a phone number to finish WeChat sign-in'**
  String get wechatPhoneBindingRequired;

  /// No description provided for @bindPhone.
  ///
  /// In en, this message translates to:
  /// **'Bind phone number'**
  String get bindPhone;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backToPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Back to previous page'**
  String get backToPreviousPage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @openNavigation.
  ///
  /// In en, this message translates to:
  /// **'Open navigation'**
  String get openNavigation;

  /// No description provided for @selectAction.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectAction;

  /// No description provided for @conversationPending.
  ///
  /// In en, this message translates to:
  /// **'Conversations are not connected yet'**
  String get conversationPending;

  /// No description provided for @maximumImageCount.
  ///
  /// In en, this message translates to:
  /// **'You can upload up to 5 images'**
  String get maximumImageCount;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Each image must be no larger than 6 MB'**
  String get imageTooLarge;

  /// No description provided for @imageReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the image. Try again later'**
  String get imageReadFailed;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get gallery;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @homeGreetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m POPi~\n'**
  String get homeGreetingTitle;

  /// No description provided for @homeWelcomeGuest.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m POPi~'**
  String get homeWelcomeGuest;

  /// No description provided for @homeWelcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}~'**
  String homeWelcomeUser(String name);

  /// No description provided for @homeWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s create something today'**
  String get homeWelcomeBody;

  /// No description provided for @homeStartIp.
  ///
  /// In en, this message translates to:
  /// **'Create a new IP account'**
  String get homeStartIp;

  /// No description provided for @homeStartRole.
  ///
  /// In en, this message translates to:
  /// **'Start with a character'**
  String get homeStartRole;

  /// No description provided for @homeStartContent.
  ///
  /// In en, this message translates to:
  /// **'Start with a topic, content or script'**
  String get homeStartContent;

  /// No description provided for @homeBannerPage.
  ///
  /// In en, this message translates to:
  /// **'Creative inspiration, image {page} of {total}'**
  String homeBannerPage(int page, int total);

  /// No description provided for @homeGreetingBody.
  ///
  /// In en, this message translates to:
  /// **'I\'ll help you\nbuild an account together!'**
  String get homeGreetingBody;

  /// No description provided for @ipGuideIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get ipGuideIntroduction;

  /// No description provided for @ipGuideIntroBefore.
  ///
  /// In en, this message translates to:
  /// **'Just '**
  String get ipGuideIntroBefore;

  /// No description provided for @ipGuideIntroFourSteps.
  ///
  /// In en, this message translates to:
  /// **'4 steps'**
  String get ipGuideIntroFourSteps;

  /// No description provided for @ipGuideIntroAfter.
  ///
  /// In en, this message translates to:
  /// **'\nto create your IP account'**
  String get ipGuideIntroAfter;

  /// No description provided for @ipGuideStart.
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get ipGuideStart;

  /// No description provided for @ipGuideStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step}'**
  String ipGuideStep(int step);

  /// No description provided for @ipDirectionQuestion.
  ///
  /// In en, this message translates to:
  /// **'What would you like to share over time?'**
  String get ipDirectionQuestion;

  /// No description provided for @ipFeelingQuestion.
  ///
  /// In en, this message translates to:
  /// **'How should your audience feel?'**
  String get ipFeelingQuestion;

  /// No description provided for @ipPresentationQuestion.
  ///
  /// In en, this message translates to:
  /// **'How should your account appear?'**
  String get ipPresentationQuestion;

  /// No description provided for @ipReviewQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your personal plan is ready to review~'**
  String get ipReviewQuestion;

  /// No description provided for @ipNextFeelings.
  ///
  /// In en, this message translates to:
  /// **'Next: audience feelings'**
  String get ipNextFeelings;

  /// No description provided for @ipNextPresentation.
  ///
  /// In en, this message translates to:
  /// **'Next: presentation'**
  String get ipNextPresentation;

  /// No description provided for @ipNextReview.
  ///
  /// In en, this message translates to:
  /// **'Next: review your plan'**
  String get ipNextReview;

  /// No description provided for @ipConfirmCreate.
  ///
  /// In en, this message translates to:
  /// **'Confirm and create'**
  String get ipConfirmCreate;

  /// No description provided for @ipReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get ipReview;

  /// No description provided for @ipContentDirection.
  ///
  /// In en, this message translates to:
  /// **'Content direction'**
  String get ipContentDirection;

  /// No description provided for @ipAudienceFeeling.
  ///
  /// In en, this message translates to:
  /// **'Audience feelings'**
  String get ipAudienceFeeling;

  /// No description provided for @ipPresentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get ipPresentation;

  /// No description provided for @ipContentFormat.
  ///
  /// In en, this message translates to:
  /// **'Content format'**
  String get ipContentFormat;

  /// No description provided for @ipTargetAudience.
  ///
  /// In en, this message translates to:
  /// **'Target audience'**
  String get ipTargetAudience;

  /// No description provided for @ipTargetAudienceValue.
  ///
  /// In en, this message translates to:
  /// **'People who want to share this feeling with you'**
  String get ipTargetAudienceValue;

  /// No description provided for @ipCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Something else, in my own words'**
  String get ipCustomHint;

  /// No description provided for @ipPrimarySelection.
  ///
  /// In en, this message translates to:
  /// **'Primary: {label}'**
  String ipPrimarySelection(String label);

  /// No description provided for @ipSecondarySelection.
  ///
  /// In en, this message translates to:
  /// **'Secondary: {label}'**
  String ipSecondarySelection(String label);

  /// No description provided for @ipMaximumSelections.
  ///
  /// In en, this message translates to:
  /// **'Choose up to two: a primary and a secondary'**
  String get ipMaximumSelections;

  /// No description provided for @ipSelectDirection.
  ///
  /// In en, this message translates to:
  /// **'Choose a content direction or write your own'**
  String get ipSelectDirection;

  /// No description provided for @ipSelectFeeling.
  ///
  /// In en, this message translates to:
  /// **'Choose an audience feeling or write your own'**
  String get ipSelectFeeling;

  /// No description provided for @ipSelectPresentation.
  ///
  /// In en, this message translates to:
  /// **'Choose a presentation style'**
  String get ipSelectPresentation;

  /// No description provided for @ipNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get ipNotSelected;

  /// No description provided for @ipAccountAvatar.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get ipAccountAvatar;

  /// No description provided for @ipNewAccount.
  ///
  /// In en, this message translates to:
  /// **'My new account'**
  String get ipNewAccount;

  /// No description provided for @ipAccountProfile.
  ///
  /// In en, this message translates to:
  /// **'IP profile'**
  String get ipAccountProfile;

  /// No description provided for @ipAccountNickname.
  ///
  /// In en, this message translates to:
  /// **'Account nickname:'**
  String get ipAccountNickname;

  /// No description provided for @ipNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Give your account a name'**
  String get ipNicknameHint;

  /// No description provided for @ipDirectionCampus.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get ipDirectionCampus;

  /// No description provided for @ipDirectionEmotion.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get ipDirectionEmotion;

  /// No description provided for @ipDirectionGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get ipDirectionGrowth;

  /// No description provided for @ipDirectionCareer.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get ipDirectionCareer;

  /// No description provided for @ipDirectionFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get ipDirectionFamily;

  /// No description provided for @ipDirectionHumor.
  ///
  /// In en, this message translates to:
  /// **'Humor'**
  String get ipDirectionHumor;

  /// No description provided for @ipDirectionMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get ipDirectionMystery;

  /// No description provided for @ipDirectionPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get ipDirectionPets;

  /// No description provided for @ipDirectionKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get ipDirectionKnowledge;

  /// No description provided for @ipFeelingAuthentic.
  ///
  /// In en, this message translates to:
  /// **'Authentic'**
  String get ipFeelingAuthentic;

  /// No description provided for @ipFeelingMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get ipFeelingMoving;

  /// No description provided for @ipFeelingHealing.
  ///
  /// In en, this message translates to:
  /// **'Healing'**
  String get ipFeelingHealing;

  /// No description provided for @ipFeelingGripping.
  ///
  /// In en, this message translates to:
  /// **'Gripping'**
  String get ipFeelingGripping;

  /// No description provided for @ipFeelingDestiny.
  ///
  /// In en, this message translates to:
  /// **'Destiny'**
  String get ipFeelingDestiny;

  /// No description provided for @ipFeelingSurprising.
  ///
  /// In en, this message translates to:
  /// **'Surprising'**
  String get ipFeelingSurprising;

  /// No description provided for @ipFeelingAuthenticDescription.
  ///
  /// In en, this message translates to:
  /// **'Natural stories that feel close to real life'**
  String get ipFeelingAuthenticDescription;

  /// No description provided for @ipFeelingMovingDescription.
  ///
  /// In en, this message translates to:
  /// **'Touch the heart and bring a tear to the eye'**
  String get ipFeelingMovingDescription;

  /// No description provided for @ipFeelingHealingDescription.
  ///
  /// In en, this message translates to:
  /// **'Warm, comforting moments to help people unwind'**
  String get ipFeelingHealingDescription;

  /// No description provided for @ipFeelingGrippingDescription.
  ///
  /// In en, this message translates to:
  /// **'A compelling pace that keeps people watching'**
  String get ipFeelingGrippingDescription;

  /// No description provided for @ipFeelingDestinyDescription.
  ///
  /// In en, this message translates to:
  /// **'Encounters and bonds that feel meant to be'**
  String get ipFeelingDestinyDescription;

  /// No description provided for @ipFeelingSurprisingDescription.
  ///
  /// In en, this message translates to:
  /// **'Unexpected endings that surprise your audience'**
  String get ipFeelingSurprisingDescription;

  /// No description provided for @ipPresentationAiReal.
  ///
  /// In en, this message translates to:
  /// **'AI human'**
  String get ipPresentationAiReal;

  /// No description provided for @ipPresentation2d.
  ///
  /// In en, this message translates to:
  /// **'2D animation'**
  String get ipPresentation2d;

  /// No description provided for @ipPresentation3d.
  ///
  /// In en, this message translates to:
  /// **'3D animation'**
  String get ipPresentation3d;

  /// No description provided for @ipPresentationLive.
  ///
  /// In en, this message translates to:
  /// **'Live action'**
  String get ipPresentationLive;

  /// No description provided for @ipFormatShortFilm.
  ///
  /// In en, this message translates to:
  /// **'Short film'**
  String get ipFormatShortFilm;

  /// No description provided for @ipFormatComicDrama.
  ///
  /// In en, this message translates to:
  /// **'Comic drama'**
  String get ipFormatComicDrama;

  /// No description provided for @ipFormatInteractiveDrama.
  ///
  /// In en, this message translates to:
  /// **'Interactive drama'**
  String get ipFormatInteractiveDrama;

  /// No description provided for @ipFormatTalkingHead.
  ///
  /// In en, this message translates to:
  /// **'Talking head'**
  String get ipFormatTalkingHead;

  /// No description provided for @ipGuideSessionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me create a new IP account.\nAccount nickname: {name}\nContent direction: {direction}\nAudience feelings: {feelings}\nPresentation: {presentation}\nContent format: {format}\nTarget audience: {audience}'**
  String ipGuideSessionPrompt(
    String name,
    String direction,
    String feelings,
    String presentation,
    String format,
    String audience,
  );

  /// No description provided for @homePromptIntro.
  ///
  /// In en, this message translates to:
  /// **'First, tell me:'**
  String get homePromptIntro;

  /// No description provided for @homePromptQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do most right now?'**
  String get homePromptQuestion;

  /// No description provided for @homePromptCreateIp.
  ///
  /// In en, this message translates to:
  /// **'Create a new IP'**
  String get homePromptCreateIp;

  /// No description provided for @homePromptImproveAccount.
  ///
  /// In en, this message translates to:
  /// **'Improve my existing account'**
  String get homePromptImproveAccount;

  /// No description provided for @homePromptHasReference.
  ///
  /// In en, this message translates to:
  /// **'I already have a reference account'**
  String get homePromptHasReference;

  /// No description provided for @homePromptUnsure.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure what to create yet'**
  String get homePromptUnsure;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated results may be inaccurate and are for reference only'**
  String get aiDisclaimer;

  /// No description provided for @composerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Say something to POPi...'**
  String get composerPlaceholder;

  /// No description provided for @selectedImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected image: {name}'**
  String selectedImageLabel(String name);

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeImage;

  /// No description provided for @addAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get addAttachment;

  /// No description provided for @attachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get attachmentTitle;

  /// No description provided for @attachmentCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachmentCamera;

  /// No description provided for @attachmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm upload'**
  String get attachmentConfirm;

  /// No description provided for @attachmentLegalNotice.
  ///
  /// In en, this message translates to:
  /// **'By uploading, you agree to the User Agreement and Privacy Policy. Please ensure you have the rights to use the uploaded materials.'**
  String get attachmentLegalNotice;

  /// No description provided for @galleryManageAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage accessible photos'**
  String get galleryManageAccess;

  /// No description provided for @galleryOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Photo access settings'**
  String get galleryOpenSettings;

  /// No description provided for @galleryAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo access is disabled'**
  String get galleryAccessDenied;

  /// No description provided for @galleryRestricted.
  ///
  /// In en, this message translates to:
  /// **'Photo access is restricted on this device'**
  String get galleryRestricted;

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accessible photos'**
  String get galleryEmpty;

  /// No description provided for @galleryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load photos. Please try again'**
  String get galleryLoadFailed;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceInput;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @searchConversations.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get searchConversations;

  /// No description provided for @newIpProject.
  ///
  /// In en, this message translates to:
  /// **'New IP project'**
  String get newIpProject;

  /// No description provided for @drawerSessions.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get drawerSessions;

  /// No description provided for @sessionItemOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for conversation {name}'**
  String sessionItemOptions(String name);

  /// No description provided for @projectCount.
  ///
  /// In en, this message translates to:
  /// **'Projects ({count})'**
  String projectCount(int count);

  /// No description provided for @projectOptions.
  ///
  /// In en, this message translates to:
  /// **'Project options'**
  String get projectOptions;

  /// No description provided for @expandAllProjects.
  ///
  /// In en, this message translates to:
  /// **'Expand all projects'**
  String get expandAllProjects;

  /// No description provided for @collapseAllProjects.
  ///
  /// In en, this message translates to:
  /// **'Collapse all projects'**
  String get collapseAllProjects;

  /// No description provided for @loginToViewProjects.
  ///
  /// In en, this message translates to:
  /// **'Log in to view projects'**
  String get loginToViewProjects;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjects;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @loadingProjects.
  ///
  /// In en, this message translates to:
  /// **'Loading projects'**
  String get loadingProjects;

  /// No description provided for @loadingProjectSessions.
  ///
  /// In en, this message translates to:
  /// **'Loading conversations'**
  String get loadingProjectSessions;

  /// No description provided for @loadingRoles.
  ///
  /// In en, this message translates to:
  /// **'Loading roles'**
  String get loadingRoles;

  /// No description provided for @loadingAssets.
  ///
  /// In en, this message translates to:
  /// **'Loading assets'**
  String get loadingAssets;

  /// No description provided for @projectsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load projects'**
  String get projectsLoadFailed;

  /// No description provided for @projectSessionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load conversations'**
  String get projectSessionsLoadFailed;

  /// No description provided for @projectItemOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for {name}'**
  String projectItemOptions(String name);

  /// No description provided for @renameProjectItem.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameProjectItem;

  /// No description provided for @projectItemName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get projectItemName;

  /// No description provided for @pinSession.
  ///
  /// In en, this message translates to:
  /// **'Pin conversation'**
  String get pinSession;

  /// No description provided for @unpinSession.
  ///
  /// In en, this message translates to:
  /// **'Unpin conversation'**
  String get unpinSession;

  /// No description provided for @deleteProjectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and all its conversations?'**
  String deleteProjectConfirm(String name);

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation {name}?'**
  String deleteSessionConfirm(String name);

  /// No description provided for @projectItemRenamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed successfully'**
  String get projectItemRenamed;

  /// No description provided for @projectItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get projectItemDeleted;

  /// No description provided for @popiConversations.
  ///
  /// In en, this message translates to:
  /// **'POPi conversations'**
  String get popiConversations;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @assets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assets;

  /// No description provided for @inspirationLibrary.
  ///
  /// In en, this message translates to:
  /// **'Inspiration'**
  String get inspirationLibrary;

  /// No description provided for @inspirationPending.
  ///
  /// In en, this message translates to:
  /// **'Inspiration is not connected yet'**
  String get inspirationPending;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile settings'**
  String get profileSettings;

  /// No description provided for @taskLifeStoryVlog.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle story vlog'**
  String get taskLifeStoryVlog;

  /// No description provided for @taskDouyinAiDrama.
  ///
  /// In en, this message translates to:
  /// **'Douyin AI comic creator'**
  String get taskDouyinAiDrama;

  /// No description provided for @taskCharacterIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Write a character introduction'**
  String get taskCharacterIntroduction;

  /// No description provided for @taskCartoonIpCharacter.
  ///
  /// In en, this message translates to:
  /// **'Create a cartoon IP character with AI and illustrators'**
  String get taskCartoonIpCharacter;

  /// No description provided for @taskHumanRender.
  ///
  /// In en, this message translates to:
  /// **'Generate a human rendering'**
  String get taskHumanRender;

  /// No description provided for @taskComedyVideoTopics.
  ///
  /// In en, this message translates to:
  /// **'Comedy video topics'**
  String get taskComedyVideoTopics;

  /// No description provided for @taskIpMonetization.
  ///
  /// In en, this message translates to:
  /// **'IP monetization models'**
  String get taskIpMonetization;

  /// No description provided for @taskBusinessPpt.
  ///
  /// In en, this message translates to:
  /// **'Minimal business presentation template'**
  String get taskBusinessPpt;

  /// No description provided for @taskShanghaiBackground.
  ///
  /// In en, this message translates to:
  /// **'Generate a bustling Shanghai skyline'**
  String get taskShanghaiBackground;

  /// No description provided for @taskVideoCreatorRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommend short-video creators'**
  String get taskVideoCreatorRecommendations;

  /// No description provided for @taskWeiboTrends.
  ///
  /// In en, this message translates to:
  /// **'Current Weibo trending topics'**
  String get taskWeiboTrends;

  /// No description provided for @taskComedyStoryVlog.
  ///
  /// In en, this message translates to:
  /// **'Comedy story vlog'**
  String get taskComedyStoryVlog;

  /// No description provided for @downloadedWorks.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {count} works'**
  String downloadedWorks(int count);

  /// No description provided for @creationHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get creationHistory;

  /// No description provided for @assetLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get assetLibrary;

  /// No description provided for @roleLibrary.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get roleLibrary;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @agentAccountMode.
  ///
  /// In en, this message translates to:
  /// **'Agent account'**
  String get agentAccountMode;

  /// No description provided for @vlog.
  ///
  /// In en, this message translates to:
  /// **'Vlog'**
  String get vlog;

  /// No description provided for @shortDrama.
  ///
  /// In en, this message translates to:
  /// **'Short drama'**
  String get shortDrama;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @aiHuman.
  ///
  /// In en, this message translates to:
  /// **'AI human'**
  String get aiHuman;

  /// No description provided for @anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get anime;

  /// No description provided for @threeD.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get threeD;

  /// No description provided for @noRoles.
  ///
  /// In en, this message translates to:
  /// **'No characters yet'**
  String get noRoles;

  /// No description provided for @noRolesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create characters to add reusable talent to your videos'**
  String get noRolesDescription;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistory;

  /// No description provided for @noWorks.
  ///
  /// In en, this message translates to:
  /// **'No works yet'**
  String get noWorks;

  /// No description provided for @noHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Start an Agent conversation\nto create your own short-video account'**
  String get noHistoryDescription;

  /// No description provided for @noWorksDescription.
  ///
  /// In en, this message translates to:
  /// **'Your images, videos, and audio will appear here'**
  String get noWorksDescription;

  /// No description provided for @goGenerate.
  ///
  /// In en, this message translates to:
  /// **'Create now'**
  String get goGenerate;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @sampleAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is there an account you like and want to learn from...'**
  String get sampleAccountQuestion;

  /// No description provided for @pointsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent {points} points'**
  String pointsSpent(int points);

  /// No description provided for @continueTask.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueTask;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @imageSavedToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Image saved to Photos'**
  String get imageSavedToPhotos;

  /// No description provided for @imageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the image. Try again later.'**
  String get imageSaveFailed;

  /// No description provided for @imageSaveAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow adding photos in system settings to save images.'**
  String get imageSaveAccessDenied;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get accountManagement;

  /// No description provided for @wechatId.
  ///
  /// In en, this message translates to:
  /// **'WeChat ID'**
  String get wechatId;

  /// No description provided for @douyin.
  ///
  /// In en, this message translates to:
  /// **'Douyin'**
  String get douyin;

  /// No description provided for @socialBound.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get socialBound;

  /// No description provided for @socialUnbound.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get socialUnbound;

  /// No description provided for @socialBindingLoading.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get socialBindingLoading;

  /// No description provided for @socialBindingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed. Retry'**
  String get socialBindingLoadFailed;

  /// No description provided for @socialBindingSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Account linked'**
  String get socialBindingSucceeded;

  /// No description provided for @socialBindingCanceled.
  ///
  /// In en, this message translates to:
  /// **'Linking canceled'**
  String get socialBindingCanceled;

  /// No description provided for @socialBindingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Authorization is unavailable. Check that the app is installed and authorization is configured.'**
  String get socialBindingUnavailable;

  /// No description provided for @socialBindingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not link account. Please try again.'**
  String get socialBindingFailed;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get logoutConfirmationTitle;

  /// No description provided for @logoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Signing out won\'t delete any data.\nYou can sign in to this account again.'**
  String get logoutDescription;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Confirm sign out'**
  String get confirmLogout;

  /// No description provided for @logoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign out. Try again later'**
  String get logoutFailed;

  /// No description provided for @regularUser.
  ///
  /// In en, this message translates to:
  /// **'Regular user'**
  String get regularUser;

  /// No description provided for @memberLevel.
  ///
  /// In en, this message translates to:
  /// **'Member {level}'**
  String memberLevel(String level);

  /// No description provided for @upgradeMembership.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgradeMembership;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get goToLogin;

  /// No description provided for @membershipStarter.
  ///
  /// In en, this message translates to:
  /// **'Starter Inspiration'**
  String get membershipStarter;

  /// No description provided for @membershipPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus Creator'**
  String get membershipPlus;

  /// No description provided for @membershipPro.
  ///
  /// In en, this message translates to:
  /// **'Pro Flagship'**
  String get membershipPro;

  /// No description provided for @membershipMax.
  ///
  /// In en, this message translates to:
  /// **'Max Studio'**
  String get membershipMax;

  /// No description provided for @limitedDiscount.
  ///
  /// In en, this message translates to:
  /// **'40% off'**
  String get limitedDiscount;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @membershipPointsValue.
  ///
  /// In en, this message translates to:
  /// **'Approx. ¥{value} per 100 points'**
  String membershipPointsValue(String value);

  /// No description provided for @pointsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'points/month'**
  String get pointsPerMonth;

  /// No description provided for @membershipPointsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Includes {packagePoints} plan points + {giftPoints} bonus points'**
  String membershipPointsBreakdown(int packagePoints, int giftPoints);

  /// No description provided for @membershipCoreBenefits.
  ///
  /// In en, this message translates to:
  /// **'Core membership benefits'**
  String get membershipCoreBenefits;

  /// No description provided for @benefitVoiceClone.
  ///
  /// In en, this message translates to:
  /// **'Voice cloning enabled'**
  String get benefitVoiceClone;

  /// No description provided for @benefitConcurrentTasks.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} concurrent tasks'**
  String benefitConcurrentTasks(int count);

  /// No description provided for @benefitCharacters.
  ///
  /// In en, this message translates to:
  /// **'Free and member characters'**
  String get benefitCharacters;

  /// No description provided for @benefitWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark-free downloads'**
  String get benefitWatermark;

  /// No description provided for @benefitVip.
  ///
  /// In en, this message translates to:
  /// **'Dedicated VIP channel'**
  String get benefitVip;

  /// No description provided for @benefitStoragePrefix.
  ///
  /// In en, this message translates to:
  /// **'Member storage limit: '**
  String get benefitStoragePrefix;

  /// No description provided for @openMembership.
  ///
  /// In en, this message translates to:
  /// **'Subscribe now'**
  String get openMembership;

  /// No description provided for @membershipComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Membership purchases are coming soon'**
  String get membershipComingSoon;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @purchaseProcessing.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the App Store…'**
  String get purchaseProcessing;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase complete. Your benefits are updated'**
  String get purchaseSuccess;

  /// No description provided for @purchaseCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled'**
  String get purchaseCanceled;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase could not be completed. Try again later'**
  String get purchaseFailed;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The App Store is currently unavailable'**
  String get storeUnavailable;

  /// No description provided for @storeProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This product was not found in the App Store. Check its configuration'**
  String get storeProductUnavailable;

  /// No description provided for @appleProductIdMissing.
  ///
  /// In en, this message translates to:
  /// **'This item does not have an Apple Product ID'**
  String get appleProductIdMissing;

  /// No description provided for @restorePurchasesRequested.
  ///
  /// In en, this message translates to:
  /// **'Purchases and membership benefits synced from your account'**
  String get restorePurchasesRequested;

  /// No description provided for @membershipPlansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No membership plans available'**
  String get membershipPlansEmpty;

  /// No description provided for @membershipPlansLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load membership plans'**
  String get membershipPlansLoadFailed;

  /// No description provided for @rechargeAndPoints.
  ///
  /// In en, this message translates to:
  /// **'Top up | Points details'**
  String get rechargeAndPoints;

  /// No description provided for @rechargeAction.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get rechargeAction;

  /// No description provided for @pointsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Points details'**
  String get pointsDetailsTitle;

  /// No description provided for @rechargePointsPackage.
  ///
  /// In en, this message translates to:
  /// **'Top up points'**
  String get rechargePointsPackage;

  /// No description provided for @rechargedPoints.
  ///
  /// In en, this message translates to:
  /// **'Purchased points'**
  String get rechargedPoints;

  /// No description provided for @giftPoints.
  ///
  /// In en, this message translates to:
  /// **'Bonus points'**
  String get giftPoints;

  /// No description provided for @pointsPackage.
  ///
  /// In en, this message translates to:
  /// **'Points package'**
  String get pointsPackage;

  /// No description provided for @pointPackagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No point packages available'**
  String get pointPackagesEmpty;

  /// No description provided for @pointPackagesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load point packages'**
  String get pointPackagesLoadFailed;

  /// No description provided for @pointsUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'This credit allowance or plan works across POPi mobile, POPi.air, and POPi.TV, with balances synced in real time.'**
  String get pointsUsageDescription;

  /// No description provided for @dailyFreePoints.
  ///
  /// In en, this message translates to:
  /// **'Daily free points'**
  String get dailyFreePoints;

  /// No description provided for @seedanceTrial.
  ///
  /// In en, this message translates to:
  /// **'Seedance 2.0 trial'**
  String get seedanceTrial;

  /// No description provided for @samplePointsDate.
  ///
  /// In en, this message translates to:
  /// **'2026-09-02 09:46'**
  String get samplePointsDate;

  /// No description provided for @pointsHistoryNotice.
  ///
  /// In en, this message translates to:
  /// **'View point activity from the last 30 days. Updates may be delayed.'**
  String get pointsHistoryNotice;

  /// No description provided for @pointsLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No point activity yet'**
  String get pointsLogEmpty;

  /// No description provided for @pointsLogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load point activity'**
  String get pointsLogLoadFailed;

  /// No description provided for @pointsLogUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Points activity'**
  String get pointsLogUnknownSource;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pointsBalance.
  ///
  /// In en, this message translates to:
  /// **'balance'**
  String get pointsBalance;

  /// No description provided for @rechargeMembershipNotice.
  ///
  /// In en, this message translates to:
  /// **'Note: Membership is required for member characters, watermark-free images and videos, and other benefits. Buying points alone does not include these benefits. Purchased points are valid for one year.'**
  String get rechargeMembershipNotice;

  /// No description provided for @customerServiceContact.
  ///
  /// In en, this message translates to:
  /// **'Customer service: 13100671900'**
  String get customerServiceContact;

  /// No description provided for @rechargeAgreementPrefix.
  ///
  /// In en, this message translates to:
  /// **'By topping up, you agree to the '**
  String get rechargeAgreementPrefix;

  /// No description provided for @userAgreement.
  ///
  /// In en, this message translates to:
  /// **'User Agreement'**
  String get userAgreement;

  /// No description provided for @conjunctionAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get conjunctionAnd;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @webPageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this page. Please try again'**
  String get webPageLoadFailed;

  /// No description provided for @webPageLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading page'**
  String get webPageLoading;

  /// No description provided for @webPageOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get webPageOpenInBrowser;

  /// No description provided for @webPageBrowserRequired.
  ///
  /// In en, this message translates to:
  /// **'Please view this page in your browser'**
  String get webPageBrowserRequired;

  /// No description provided for @webPageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh page'**
  String get webPageRefresh;

  /// No description provided for @nicknameRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname*'**
  String get nicknameRequiredLabel;

  /// No description provided for @nicknameHelp.
  ///
  /// In en, this message translates to:
  /// **'Chinese, English, and numbers are supported. Up to 15 characters.'**
  String get nicknameHelp;

  /// No description provided for @nicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get nicknameRequired;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update your profile. Try again later'**
  String get profileUpdateFailed;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'“Helping people express themselves better”'**
  String get splashTagline;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
