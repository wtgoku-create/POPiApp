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

  /// No description provided for @v2NetworkError.
  ///
  /// In en, this message translates to:
  /// **'Request failed. Check your connection and try again.'**
  String get v2NetworkError;

  /// No description provided for @v2GenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get v2GenerationFailed;

  /// No description provided for @v2CustomAnswer.
  ///
  /// In en, this message translates to:
  /// **'Enter another answer'**
  String get v2CustomAnswer;

  /// No description provided for @v2UploadInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some files have an unsupported format or size. Select them again.'**
  String get v2UploadInvalid;

  /// No description provided for @v2RoleInstructions.
  ///
  /// In en, this message translates to:
  /// **'Character instructions'**
  String get v2RoleInstructions;

  /// No description provided for @v2RoleReferences.
  ///
  /// In en, this message translates to:
  /// **'Add reference images (up to 5)'**
  String get v2RoleReferences;

  /// No description provided for @v2RoleLimit.
  ///
  /// In en, this message translates to:
  /// **'Link up to 5 characters'**
  String get v2RoleLimit;

  /// No description provided for @v2NoConversationSelected.
  ///
  /// In en, this message translates to:
  /// **'No conversation selected'**
  String get v2NoConversationSelected;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'POPi'**
  String get appTitle;

  /// No description provided for @hideKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get hideKeyboard;

  /// No description provided for @roleGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with characters'**
  String get roleGuideTitle;

  /// No description provided for @roleNotReadyForVideo.
  ///
  /// In en, this message translates to:
  /// **'This character\'s profile or reference images are not ready'**
  String get roleNotReadyForVideo;

  /// No description provided for @roleRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the creation request. Try again'**
  String get roleRequestFailed;

  /// No description provided for @roleStoryRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the story request'**
  String get roleStoryRequestFailed;

  /// No description provided for @roleLoadingStories.
  ///
  /// In en, this message translates to:
  /// **'Finding stories...'**
  String get roleLoadingStories;

  /// No description provided for @roleNoStories.
  ///
  /// In en, this message translates to:
  /// **'No story suggestions yet'**
  String get roleNoStories;

  /// No description provided for @roleAccountFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'IP account'**
  String get roleAccountFallbackTitle;

  /// No description provided for @roleNoVideoModels.
  ///
  /// In en, this message translates to:
  /// **'No video models available'**
  String get roleNoVideoModels;

  /// No description provided for @roleModelConfigured.
  ///
  /// In en, this message translates to:
  /// **'Model configured'**
  String get roleModelConfigured;

  /// No description provided for @roleTaskPaused.
  ///
  /// In en, this message translates to:
  /// **'Creation paused'**
  String get roleTaskPaused;

  /// No description provided for @roleStatusPausing.
  ///
  /// In en, this message translates to:
  /// **'Pausing'**
  String get roleStatusPausing;

  /// No description provided for @roleTaskPausing.
  ///
  /// In en, this message translates to:
  /// **'Pausing creation...'**
  String get roleTaskPausing;

  /// No description provided for @roleTaskCanceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling creation...'**
  String get roleTaskCanceling;

  /// No description provided for @roleStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get roleStatusPaused;

  /// No description provided for @roleStatusCanceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling'**
  String get roleStatusCanceling;

  /// No description provided for @roleGenerationPausedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your current plan is saved. You can resume creation.'**
  String get roleGenerationPausedDescription;

  /// No description provided for @chatTaskCanceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling after the current stage'**
  String get chatTaskCanceling;

  /// No description provided for @rolePauseProduction.
  ///
  /// In en, this message translates to:
  /// **'Pause creation'**
  String get rolePauseProduction;

  /// No description provided for @roleResumeProduction.
  ///
  /// In en, this message translates to:
  /// **'Resume creation'**
  String get roleResumeProduction;

  /// No description provided for @roleConfirmVideo.
  ///
  /// In en, this message translates to:
  /// **'Confirm video generation'**
  String get roleConfirmVideo;

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

  /// No description provided for @roleConfirmSelection.
  ///
  /// In en, this message translates to:
  /// **'Confirm selection'**
  String get roleConfirmSelection;

  /// No description provided for @roleSelectionLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {count} characters'**
  String roleSelectionLimit(int count);

  /// No description provided for @removeRole.
  ///
  /// In en, this message translates to:
  /// **'Remove role'**
  String get removeRole;

  /// No description provided for @removeAsset.
  ///
  /// In en, this message translates to:
  /// **'Remove asset'**
  String get removeAsset;

  /// No description provided for @assetSelectionLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {count} media items'**
  String assetSelectionLimit(int count);

  /// No description provided for @chatRolePrompt.
  ///
  /// In en, this message translates to:
  /// **'Create using the selected characters.'**
  String get chatRolePrompt;

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

  /// No description provided for @roleReconfirmVideo.
  ///
  /// In en, this message translates to:
  /// **'Confirm video again'**
  String get roleReconfirmVideo;

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

  /// No description provided for @roleCollapseProfile.
  ///
  /// In en, this message translates to:
  /// **'Collapse full character profile'**
  String get roleCollapseProfile;

  /// No description provided for @roleFullProfileVersion.
  ///
  /// In en, this message translates to:
  /// **'View full character profile {version}'**
  String roleFullProfileVersion(String version);

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

  /// No description provided for @roleStartCreating.
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get roleStartCreating;

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

  /// No description provided for @chatVideoProgress.
  ///
  /// In en, this message translates to:
  /// **'Video generation progress'**
  String get chatVideoProgress;

  /// No description provided for @chatStoryboardReview.
  ///
  /// In en, this message translates to:
  /// **'Storyboard ready, awaiting video confirmation'**
  String get chatStoryboardReview;

  /// No description provided for @chatTaskPausing.
  ///
  /// In en, this message translates to:
  /// **'Pausing after the current stage'**
  String get chatTaskPausing;

  /// No description provided for @chatStageGenerateVideo.
  ///
  /// In en, this message translates to:
  /// **'Generate video'**
  String get chatStageGenerateVideo;

  /// No description provided for @chatStageInspectResult.
  ///
  /// In en, this message translates to:
  /// **'Inspect result'**
  String get chatStageInspectResult;

  /// No description provided for @roleStoryboardContent.
  ///
  /// In en, this message translates to:
  /// **'Storyboard video prompt'**
  String get roleStoryboardContent;

  /// No description provided for @roleStoryboardShot.
  ///
  /// In en, this message translates to:
  /// **'Shot {index} · {duration} s'**
  String roleStoryboardShot(int index, String duration);

  /// No description provided for @roleVideoModelPrompt.
  ///
  /// In en, this message translates to:
  /// **'Video model prompt'**
  String get roleVideoModelPrompt;

  /// No description provided for @videoFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Play fullscreen'**
  String get videoFullscreen;

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

  /// No description provided for @roleDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get roleDuration;

  /// No description provided for @roleNoImageModels.
  ///
  /// In en, this message translates to:
  /// **'No image models available'**
  String get roleNoImageModels;

  /// No description provided for @roleDurationAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get roleDurationAutomatic;

  /// No description provided for @roleDurationCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get roleDurationCustom;

  /// No description provided for @roleDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String roleDurationSeconds(String seconds);

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

  /// No description provided for @roleEditCreationProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit role for this creation'**
  String get roleEditCreationProfile;

  /// No description provided for @roleEditCreationArchive.
  ///
  /// In en, this message translates to:
  /// **'Edit profile for this creation'**
  String get roleEditCreationArchive;

  /// No description provided for @roleCreationEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the role for this creation'**
  String get roleCreationEditTitle;

  /// No description provided for @roleCreationEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit the description, appearance, personality, expression style, audience and content tags.'**
  String get roleCreationEditDescription;

  /// No description provided for @roleFieldInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid field format'**
  String get roleFieldInvalidFormat;

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

  /// No description provided for @ipProjects.
  ///
  /// In en, this message translates to:
  /// **'IP projects'**
  String get ipProjects;

  /// No description provided for @teachingCenter.
  ///
  /// In en, this message translates to:
  /// **'Learning center'**
  String get teachingCenter;

  /// No description provided for @ipAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'IP Account Management'**
  String get ipAccountsTitle;

  /// No description provided for @deleteIpAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this IP account?'**
  String get deleteIpAccountTitle;

  /// No description provided for @deleteIpAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'The account will be archived and removed from the account list. Works, conversations and account data will be preserved.'**
  String get deleteIpAccountDescription;

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

  /// No description provided for @ipAccountHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Home'**
  String get ipAccountHomeTitle;

  /// No description provided for @ipAccountPreferences.
  ///
  /// In en, this message translates to:
  /// **'Account Preferences'**
  String get ipAccountPreferences;

  /// No description provided for @accountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountCreate;

  /// No description provided for @accountArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get accountArchived;

  /// No description provided for @accountActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountActive;

  /// No description provided for @accountArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive account'**
  String get accountArchive;

  /// No description provided for @accountRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore account'**
  String get accountRestore;

  /// No description provided for @accountArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Creations, conversations and account details will be kept. You can restore this account at any time.'**
  String get accountArchiveConfirm;

  /// No description provided for @accountMemory.
  ///
  /// In en, this message translates to:
  /// **'Account memory'**
  String get accountMemory;

  /// No description provided for @accountUserPrompt.
  ///
  /// In en, this message translates to:
  /// **'Account Positioning'**
  String get accountUserPrompt;

  /// No description provided for @accountPositioningHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the account\'s theme, style and creative direction'**
  String get accountPositioningHint;

  /// No description provided for @accountConstraints.
  ///
  /// In en, this message translates to:
  /// **'Creative constraints'**
  String get accountConstraints;

  /// No description provided for @accountCustomOption.
  ///
  /// In en, this message translates to:
  /// **'Custom option'**
  String get accountCustomOption;

  /// No description provided for @accountInputInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a value within the selection and length limits'**
  String get accountInputInvalid;

  /// No description provided for @accountTitleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an account name of up to 15 characters'**
  String get accountTitleInvalid;

  /// No description provided for @accountRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get accountRenameTitle;

  /// No description provided for @accountRenameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change the account nickname to:\n{title}'**
  String accountRenameConfirm(String title);

  /// No description provided for @accountArchives.
  ///
  /// In en, this message translates to:
  /// **'Creation archives'**
  String get accountArchives;

  /// No description provided for @accountArchiveSearch.
  ///
  /// In en, this message translates to:
  /// **'Search titles or summaries'**
  String get accountArchiveSearch;

  /// No description provided for @accountLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get accountLoadMore;

  /// No description provided for @accountArchiveVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get accountArchiveVersion;

  /// No description provided for @accountArchiveSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get accountArchiveSummary;

  /// No description provided for @accountArchiveBrief.
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get accountArchiveBrief;

  /// No description provided for @accountArchiveTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get accountArchiveTopic;

  /// No description provided for @accountArchiveScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get accountArchiveScript;

  /// No description provided for @accountArchiveStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Storyboard video prompt'**
  String get accountArchiveStoryboard;

  /// No description provided for @accountArchiveCast.
  ///
  /// In en, this message translates to:
  /// **'Cast snapshot'**
  String get accountArchiveCast;

  /// No description provided for @accountArchiveGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generation parameters'**
  String get accountArchiveGeneration;

  /// No description provided for @accountOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'View conversation'**
  String get accountOpenConversation;

  /// No description provided for @ipAccountPositioning.
  ///
  /// In en, this message translates to:
  /// **'Account Positioning'**
  String get ipAccountPositioning;

  /// No description provided for @ipAccountFieldEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get ipAccountFieldEmpty;

  /// No description provided for @ipAccountEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ipAccountEdit;

  /// No description provided for @ipAccountSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get ipAccountSave;

  /// No description provided for @ipAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account details saved'**
  String get ipAccountSaved;

  /// No description provided for @ipAccountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load account details. Please retry.'**
  String get ipAccountLoadFailed;

  /// No description provided for @ipAccountResourcesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load project assets and roles'**
  String get ipAccountResourcesFailed;

  /// No description provided for @ipAccountAssets.
  ///
  /// In en, this message translates to:
  /// **'Project Assets'**
  String get ipAccountAssets;

  /// No description provided for @ipAccountRoles.
  ///
  /// In en, this message translates to:
  /// **'Project Roles'**
  String get ipAccountRoles;

  /// No description provided for @ipAccountNoAssets.
  ///
  /// In en, this message translates to:
  /// **'No creations yet'**
  String get ipAccountNoAssets;

  /// No description provided for @ipAccountNoRoles.
  ///
  /// In en, this message translates to:
  /// **'No project roles yet'**
  String get ipAccountNoRoles;

  /// No description provided for @ipAccountCountSeparator.
  ///
  /// In en, this message translates to:
  /// **': '**
  String get ipAccountCountSeparator;

  /// No description provided for @ipAccountAssetsEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'No creations yet. Start creating with your Agent.'**
  String get ipAccountAssetsEmptyPrompt;

  /// No description provided for @ipAccountRolesEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add roles to build your creative world.'**
  String get ipAccountRolesEmptyPrompt;

  /// No description provided for @ipAccountManageRoles.
  ///
  /// In en, this message translates to:
  /// **'Manage Project Roles'**
  String get ipAccountManageRoles;

  /// No description provided for @ipAccountRoleLimit.
  ///
  /// In en, this message translates to:
  /// **'Add up to 20 roles'**
  String get ipAccountRoleLimit;

  /// No description provided for @ipAccountPublish.
  ///
  /// In en, this message translates to:
  /// **'Create Content'**
  String get ipAccountPublish;

  /// No description provided for @ipAccountPublishEstimate.
  ///
  /// In en, this message translates to:
  /// **'About 1 min'**
  String get ipAccountPublishEstimate;

  /// No description provided for @ipAccountPublishReady.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready. Start with a topic, idea, script, or material.'**
  String get ipAccountPublishReady;

  /// No description provided for @ipAccountStartContent.
  ///
  /// In en, this message translates to:
  /// **'Start New Content'**
  String get ipAccountStartContent;

  /// No description provided for @ipAccountContinueConversation.
  ///
  /// In en, this message translates to:
  /// **'Continue Conversation'**
  String get ipAccountContinueConversation;

  /// No description provided for @ipAccountStartPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me create new content based on this account\'s positioning.'**
  String get ipAccountStartPrompt;

  /// No description provided for @ipAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account is paused'**
  String get ipAccountUnavailable;

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
  /// **'New project'**
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

  /// No description provided for @imageShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share image. Please try again'**
  String get imageShareFailed;

  /// No description provided for @mediaShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share media. Please try again'**
  String get mediaShareFailed;

  /// No description provided for @mediaPreviewPosition.
  ///
  /// In en, this message translates to:
  /// **'Item {index} of {count}'**
  String mediaPreviewPosition(int index, int count);

  /// No description provided for @imagePreviewPosition.
  ///
  /// In en, this message translates to:
  /// **'Image {index} of {count}'**
  String imagePreviewPosition(int index, int count);

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

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activities;

  /// No description provided for @activityCenter.
  ///
  /// In en, this message translates to:
  /// **'Activity Center'**
  String get activityCenter;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activities available'**
  String get activityEmpty;

  /// No description provided for @activityUntitled.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityUntitled;

  /// No description provided for @activityNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No activity details available'**
  String get activityNoDescription;

  /// No description provided for @activityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load activities. Please try again'**
  String get activityLoadFailed;

  /// No description provided for @activityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This activity has ended or is not available yet'**
  String get activityUnavailable;

  /// No description provided for @activityOfficialCode.
  ///
  /// In en, this message translates to:
  /// **'Official redemption code'**
  String get activityOfficialCode;

  /// No description provided for @activityCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter redemption code'**
  String get activityCodePlaceholder;

  /// No description provided for @activityOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get activityOrderNumber;

  /// No description provided for @activityOrderPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Paste your Douyin order number'**
  String get activityOrderPlaceholder;

  /// No description provided for @activityMemberRestriction.
  ///
  /// In en, this message translates to:
  /// **'This activity is limited to {levels}'**
  String activityMemberRestriction(String levels);

  /// No description provided for @activityMemberLevel.
  ///
  /// In en, this message translates to:
  /// **'Membership level {level}'**
  String activityMemberLevel(int level);

  /// No description provided for @activityExchangeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Redeemed successfully'**
  String get activityExchangeSuccess;

  /// No description provided for @activityExchangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to redeem. Please try again later'**
  String get activityExchangeFailed;

  /// No description provided for @activityRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Redeemed successfully. Membership information could not refresh; check again later'**
  String get activityRefreshFailed;

  /// No description provided for @activityQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity QR code'**
  String get activityQrTitle;

  /// No description provided for @activityFinalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Final confirmation'**
  String get activityFinalConfirmation;

  /// No description provided for @activityRefundNotice.
  ///
  /// In en, this message translates to:
  /// **'Once this membership benefit is claimed, the course is considered redeemed and used, and you will no longer be able to request a refund from POPi. To confirm that you fully understand this rule, enter the following text:'**
  String get activityRefundNotice;

  /// No description provided for @activityConfirmationPhrase.
  ///
  /// In en, this message translates to:
  /// **'I understand this redemption is non-refundable'**
  String get activityConfirmationPhrase;

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

  /// No description provided for @imageUploadProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String imageUploadProgress(int percent);

  /// No description provided for @imageUploadProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get imageUploadProcessing;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get imageUploadFailed;

  /// No description provided for @imageUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get imageUploadComplete;

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

  /// No description provided for @ipGuideIntroFiveSteps.
  ///
  /// In en, this message translates to:
  /// **'5 steps'**
  String get ipGuideIntroFiveSteps;

  /// No description provided for @ipDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue your draft or create a new IP?'**
  String get ipDraftTitle;

  /// No description provided for @ipDraftDetected.
  ///
  /// In en, this message translates to:
  /// **'An account positioning draft was found.'**
  String get ipDraftDetected;

  /// No description provided for @ipDraftDescription.
  ///
  /// In en, this message translates to:
  /// **'Continue to return to your saved step. Starting again replaces this draft. Existing projects, content, and assets will be kept.'**
  String get ipDraftDescription;

  /// No description provided for @ipDraftRestart.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get ipDraftRestart;

  /// No description provided for @ipDraftResume.
  ///
  /// In en, this message translates to:
  /// **'Continue draft'**
  String get ipDraftResume;

  /// No description provided for @ipDraftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your draft. Please retry.'**
  String get ipDraftSaveFailed;

  /// No description provided for @ipNextAudience.
  ///
  /// In en, this message translates to:
  /// **'Next: Target audience'**
  String get ipNextAudience;

  /// No description provided for @ipAudienceQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who is your account for?'**
  String get ipAudienceQuestion;

  /// No description provided for @ipSelectAudience.
  ///
  /// In en, this message translates to:
  /// **'Choose an audience or enter your own'**
  String get ipSelectAudience;

  /// No description provided for @ipSelectNickname.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for your account'**
  String get ipSelectNickname;

  /// No description provided for @ipReselect.
  ///
  /// In en, this message translates to:
  /// **'Choose again'**
  String get ipReselect;

  /// No description provided for @ipCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get ipCreating;

  /// No description provided for @ipCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Creation is incomplete. Your draft is saved. Please retry.'**
  String get ipCreateFailed;

  /// No description provided for @ipCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created!'**
  String get ipCreateSuccess;

  /// No description provided for @ipCreateSuccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Every piece of content you publish will build your account here.'**
  String get ipCreateSuccessDescription;

  /// No description provided for @ipCreateFirstRole.
  ///
  /// In en, this message translates to:
  /// **'Create your first character'**
  String get ipCreateFirstRole;

  /// No description provided for @ipCreateFirstContent.
  ///
  /// In en, this message translates to:
  /// **'Make your first content'**
  String get ipCreateFirstContent;

  /// No description provided for @ipOpenProject.
  ///
  /// In en, this message translates to:
  /// **'Open account project'**
  String get ipOpenProject;

  /// No description provided for @ipFirstRolePrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me create the first character based on this account\'s positioning.'**
  String get ipFirstRolePrompt;

  /// No description provided for @ipFirstContentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Help me make the first piece of content based on this account\'s positioning.'**
  String get ipFirstContentPrompt;

  /// No description provided for @ipAudienceStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get ipAudienceStudents;

  /// No description provided for @ipAudienceWorkers.
  ///
  /// In en, this message translates to:
  /// **'Professionals'**
  String get ipAudienceWorkers;

  /// No description provided for @ipAudienceFamilies.
  ///
  /// In en, this message translates to:
  /// **'Families'**
  String get ipAudienceFamilies;

  /// No description provided for @ipAudienceAnimeFans.
  ///
  /// In en, this message translates to:
  /// **'Anime fans'**
  String get ipAudienceAnimeFans;

  /// No description provided for @ipAudiencePetLovers.
  ///
  /// In en, this message translates to:
  /// **'Pet lovers'**
  String get ipAudiencePetLovers;

  /// No description provided for @ipAudienceSeniors.
  ///
  /// In en, this message translates to:
  /// **'Seniors'**
  String get ipAudienceSeniors;

  /// No description provided for @ipAudienceStudentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Campus life, learning, and the interests of young people'**
  String get ipAudienceStudentsDescription;

  /// No description provided for @ipAudienceWorkersDescription.
  ///
  /// In en, this message translates to:
  /// **'Work life, career growth, and everyday pressures'**
  String get ipAudienceWorkersDescription;

  /// No description provided for @ipAudienceFamiliesDescription.
  ///
  /// In en, this message translates to:
  /// **'Parenting, family life, and spending time with children'**
  String get ipAudienceFamiliesDescription;

  /// No description provided for @ipAudienceAnimeFansDescription.
  ///
  /// In en, this message translates to:
  /// **'Anime characters, fantasy stories, and creative worlds'**
  String get ipAudienceAnimeFansDescription;

  /// No description provided for @ipAudiencePetLoversDescription.
  ///
  /// In en, this message translates to:
  /// **'Pets, playful moments, and comforting characters'**
  String get ipAudiencePetLoversDescription;

  /// No description provided for @ipAudienceSeniorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Healthy living, hobbies, and life after retirement'**
  String get ipAudienceSeniorsDescription;

  /// No description provided for @ipPresentationPets.
  ///
  /// In en, this message translates to:
  /// **'Anthropomorphic pets'**
  String get ipPresentationPets;

  /// No description provided for @ipPresentationClay.
  ///
  /// In en, this message translates to:
  /// **'Clay animation'**
  String get ipPresentationClay;

  /// No description provided for @ipPresentationInk.
  ///
  /// In en, this message translates to:
  /// **'Chinese ink painting'**
  String get ipPresentationInk;

  /// No description provided for @ipVisualStyle.
  ///
  /// In en, this message translates to:
  /// **'Visual style'**
  String get ipVisualStyle;

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

  /// No description provided for @guestTagline.
  ///
  /// In en, this message translates to:
  /// **'Your short-video account advisor'**
  String get guestTagline;

  /// No description provided for @guestStartCreating.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create'**
  String get guestStartCreating;

  /// No description provided for @guestVoiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get guestVoiceInput;

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

  /// No description provided for @composerRunning.
  ///
  /// In en, this message translates to:
  /// **'Session is running'**
  String get composerRunning;

  /// No description provided for @sessionWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi there!'**
  String get sessionWelcomeTitle;

  /// No description provided for @sessionWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Tell me, what would you like to create?'**
  String get sessionWelcomeBody;

  /// No description provided for @composerExpandInput.
  ///
  /// In en, this message translates to:
  /// **'Expand input'**
  String get composerExpandInput;

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

  /// No description provided for @attachmentFeaturePending.
  ///
  /// In en, this message translates to:
  /// **'Feature under development'**
  String get attachmentFeaturePending;

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

  /// No description provided for @drawerNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New project chat'**
  String get drawerNewConversation;

  /// No description provided for @drawerViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get drawerViewAll;

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

  /// No description provided for @notificationSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationSystem;

  /// No description provided for @notificationPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get notificationPersonal;

  /// No description provided for @notificationNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get notificationNew;

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationUnread;

  /// No description provided for @notificationUntitled.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationUntitled;

  /// No description provided for @notificationLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get notificationLearnMore;

  /// No description provided for @notificationDetail.
  ///
  /// In en, this message translates to:
  /// **'Notification Details'**
  String get notificationDetail;

  /// No description provided for @notificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationEmpty;

  /// No description provided for @notificationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications. Please retry.'**
  String get notificationLoadFailed;

  /// No description provided for @notificationLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get notificationLoadMore;

  /// No description provided for @notificationLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more notifications. Retry'**
  String get notificationLoadMoreFailed;

  /// No description provided for @notificationReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not mark as read. Reopen the notification to retry.'**
  String get notificationReadFailed;

  /// No description provided for @notificationLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view notifications'**
  String get notificationLoginRequired;

  /// No description provided for @notificationImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get notificationImageFailed;

  /// No description provided for @notificationViewImage.
  ///
  /// In en, this message translates to:
  /// **'View notification image'**
  String get notificationViewImage;

  /// No description provided for @notificationDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String notificationDaysAgo(int days);

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

  /// No description provided for @creationHistoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load creation history'**
  String get creationHistoryLoadFailed;

  /// No description provided for @searchCreationHistory.
  ///
  /// In en, this message translates to:
  /// **'Search creation history'**
  String get searchCreationHistory;

  /// No description provided for @noMatchingHistory.
  ///
  /// In en, this message translates to:
  /// **'No matching history'**
  String get noMatchingHistory;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

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

  /// No description provided for @sessionArtifactExported.
  ///
  /// In en, this message translates to:
  /// **'Document exported'**
  String get sessionArtifactExported;

  /// No description provided for @sessionArtifactExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the document. Try again later.'**
  String get sessionArtifactExportFailed;

  /// No description provided for @sessionArtifactSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get sessionArtifactSaved;

  /// No description provided for @sessionArtifactSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file. Try again later.'**
  String get sessionArtifactSaveFailed;

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

  /// No description provided for @videoSavedToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Video saved to Photos'**
  String get videoSavedToPhotos;

  /// No description provided for @videoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the video. Try again later.'**
  String get videoSaveFailed;

  /// No description provided for @videoSaveAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow adding photos in system settings to save videos.'**
  String get videoSaveAccessDenied;

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

  /// No description provided for @cancelAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get cancelAccount;

  /// No description provided for @cancelAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get cancelAccountTitle;

  /// No description provided for @cancelAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. You will no longer be able to sign in, and all devices will be signed out.\nYour phone number and linked accounts cannot automatically register a new account. Historical data and works will be retained.'**
  String get cancelAccountDescription;

  /// No description provided for @confirmCancelAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get confirmCancelAccount;

  /// No description provided for @cancelAccountSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get cancelAccountSucceeded;

  /// No description provided for @cancelAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete your account. Try again later'**
  String get cancelAccountFailed;

  /// No description provided for @regularUser.
  ///
  /// In en, this message translates to:
  /// **'Regular user'**
  String get regularUser;

  /// No description provided for @memberLevel.
  ///
  /// In en, this message translates to:
  /// **'{level} member'**
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

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get paymentTitle;

  /// No description provided for @paymentChooseMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentChooseMethod;

  /// No description provided for @paymentWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat Pay'**
  String get paymentWechat;

  /// No description provided for @paymentAlipay.
  ///
  /// In en, this message translates to:
  /// **'Alipay'**
  String get paymentAlipay;

  /// No description provided for @paymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get paymentConfirm;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment amount'**
  String get paymentAmount;

  /// No description provided for @paymentPerYear.
  ///
  /// In en, this message translates to:
  /// **'/year'**
  String get paymentPerYear;

  /// No description provided for @paymentPoints.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get paymentPoints;

  /// No description provided for @paymentGrantPoints.
  ///
  /// In en, this message translates to:
  /// **'Points granted: {points}'**
  String paymentGrantPoints(int points);

  /// No description provided for @paymentCatalogPrice.
  ///
  /// In en, this message translates to:
  /// **'Plan price. Your order determines the final charge'**
  String get paymentCatalogPrice;

  /// No description provided for @paymentCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get paymentCheckAgain;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Payment is processing. Benefits will update once delivered'**
  String get paymentProcessing;

  /// No description provided for @paymentCanceledPending.
  ///
  /// In en, this message translates to:
  /// **'Payment canceled. Order status is awaiting confirmation'**
  String get paymentCanceledPending;

  /// No description provided for @paymentUnknown.
  ///
  /// In en, this message translates to:
  /// **'Payment status is unavailable. Check your bill before paying again'**
  String get paymentUnknown;

  /// No description provided for @paymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Order incomplete or refunded. Benefits have not been confirmed'**
  String get paymentNotCompleted;

  /// No description provided for @paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment service is unavailable. Try again later'**
  String get paymentUnavailable;

  /// No description provided for @paymentAppNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed or unavailable'**
  String get paymentAppNotInstalled;

  /// No description provided for @paymentRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get paymentRetry;

  /// No description provided for @paymentDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get paymentDone;

  /// No description provided for @paymentOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get paymentOrderNumber;

  /// No description provided for @paymentCopyOrder.
  ///
  /// In en, this message translates to:
  /// **'Copy order number'**
  String get paymentCopyOrder;

  /// No description provided for @paymentOrderCopied.
  ///
  /// In en, this message translates to:
  /// **'Order number copied'**
  String get paymentOrderCopied;

  /// No description provided for @paymentPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Other unconfirmed orders'**
  String get paymentPendingOrders;

  /// No description provided for @paymentNewPurchase.
  ///
  /// In en, this message translates to:
  /// **'Buy again'**
  String get paymentNewPurchase;

  /// No description provided for @paymentNewPurchaseWarning.
  ///
  /// In en, this message translates to:
  /// **'The original order may still be processing. Check your WeChat or Alipay bill first. Buying again creates a new order and may result in a duplicate charge.'**
  String get paymentNewPurchaseWarning;

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

  /// No description provided for @membershipCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get membershipCurrentPlan;

  /// No description provided for @membershipBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get membershipBuyNow;

  /// No description provided for @membershipAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re already {level}'**
  String membershipAlreadyMember(String level);

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
  /// **'This credit allowance or plan works across POPi mobile, POPi.Art, and POPi.TV, with balances synced in real time.'**
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

  /// No description provided for @aboutPopiAi.
  ///
  /// In en, this message translates to:
  /// **'About POPi AI'**
  String get aboutPopiAi;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and Privacy'**
  String get privacyConsentTitle;

  /// No description provided for @privacyConsentMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to POPi! Before using the app, please read our User Agreement and Privacy Policy to understand how we collect, use and protect your personal information, and the rights available to you.\n\nFor sign-in, AI creation and saving content, we process account information, content you submit, and necessary device and log information as described in the policy. Permissions such as photo library access are requested when you use the relevant features.\n\nBy tapping “Agree & Continue”, you confirm that you have read and agree to these terms and policies.'**
  String get privacyConsentMessage;

  /// No description provided for @privacyConsentAccept.
  ///
  /// In en, this message translates to:
  /// **'Agree & Continue'**
  String get privacyConsentAccept;

  /// No description provided for @privacyConsentDecline.
  ///
  /// In en, this message translates to:
  /// **'Disagree'**
  String get privacyConsentDecline;

  /// No description provided for @privacyConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please read and agree to the User Agreement and Privacy Policy to use POPi.'**
  String get privacyConsentRequired;

  /// No description provided for @privacyConsentReview.
  ///
  /// In en, this message translates to:
  /// **'Review Terms and Privacy'**
  String get privacyConsentReview;

  /// No description provided for @privacyConsentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save your choice. Please tap Agree & Continue again.'**
  String get privacyConsentSaveFailed;

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

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'POPi is working…'**
  String get chatThinking;

  /// No description provided for @chatQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get chatQueued;

  /// No description provided for @chatWaitingExternal.
  ///
  /// In en, this message translates to:
  /// **'Waiting for results'**
  String get chatWaitingExternal;

  /// No description provided for @chatCanceling.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get chatCanceling;

  /// No description provided for @chatTopicSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected story'**
  String get chatTopicSelected;

  /// No description provided for @chatTopicConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Topic confirmed'**
  String get chatTopicConfirmed;

  /// No description provided for @chatCollapseStory.
  ///
  /// In en, this message translates to:
  /// **'Collapse story'**
  String get chatCollapseStory;

  /// No description provided for @chatExpandStory.
  ///
  /// In en, this message translates to:
  /// **'Expand story'**
  String get chatExpandStory;

  /// No description provided for @chatGenerationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Generation plan confirmed'**
  String get chatGenerationConfirmed;

  /// No description provided for @chatGenerationCanceled.
  ///
  /// In en, this message translates to:
  /// **'Generation plan canceled'**
  String get chatGenerationCanceled;

  /// No description provided for @chatReferenceImage.
  ///
  /// In en, this message translates to:
  /// **'Reference image'**
  String get chatReferenceImage;

  /// No description provided for @chatImageStyle.
  ///
  /// In en, this message translates to:
  /// **'Image style'**
  String get chatImageStyle;

  /// No description provided for @chatStyleLibrary.
  ///
  /// In en, this message translates to:
  /// **'Style library'**
  String get chatStyleLibrary;

  /// No description provided for @chatStyleUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted style'**
  String get chatStyleUnrestricted;

  /// No description provided for @chatUnrestrictedStyle.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted style'**
  String get chatUnrestrictedStyle;

  /// No description provided for @chatGenerationRequirements.
  ///
  /// In en, this message translates to:
  /// **'Additional requirements'**
  String get chatGenerationRequirements;

  /// No description provided for @chatInvalidGeneration.
  ///
  /// In en, this message translates to:
  /// **'Check the model, parameters and reference materials'**
  String get chatInvalidGeneration;

  /// No description provided for @chatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get chatUnavailable;

  /// No description provided for @chatGenerationTask.
  ///
  /// In en, this message translates to:
  /// **'Generation task'**
  String get chatGenerationTask;

  /// No description provided for @chatExpandTask.
  ///
  /// In en, this message translates to:
  /// **'Expand task'**
  String get chatExpandTask;

  /// No description provided for @chatCollapseTask.
  ///
  /// In en, this message translates to:
  /// **'Collapse task'**
  String get chatCollapseTask;

  /// No description provided for @chatGenerationWorking.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get chatGenerationWorking;

  /// No description provided for @chatGenerationWorkingHint.
  ///
  /// In en, this message translates to:
  /// **'Creating your work...'**
  String get chatGenerationWorkingHint;

  /// No description provided for @chatGenerationTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get chatGenerationTaskCompleted;

  /// No description provided for @chatImageGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Image generation failed'**
  String get chatImageGenerationFailed;

  /// No description provided for @chatVideoGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Video generation failed'**
  String get chatVideoGenerationFailed;

  /// No description provided for @chatTextGenerationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Text generation timed out. Please try again'**
  String get chatTextGenerationTimeout;

  /// No description provided for @chatTextGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Text generation failed. Please try again'**
  String get chatTextGenerationFailed;

  /// No description provided for @chatScriptGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Script generation failed. Please try again'**
  String get chatScriptGenerationFailed;

  /// No description provided for @chatTopicGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Topic generation failed. Please try again'**
  String get chatTopicGenerationFailed;

  /// No description provided for @chatResultCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'The video integrity check failed. The generated result has been kept'**
  String get chatResultCheckFailed;

  /// No description provided for @chatOutputValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'The generated result failed validation. Please try again'**
  String get chatOutputValidationFailed;

  /// No description provided for @chatStoryboardMissing.
  ///
  /// In en, this message translates to:
  /// **'The saved storyboard is missing. Confirm the storyboard before generating'**
  String get chatStoryboardMissing;

  /// No description provided for @chatVideoMissing.
  ///
  /// In en, this message translates to:
  /// **'The generated video could not be found. Please try again'**
  String get chatVideoMissing;

  /// No description provided for @chatTaskInputChanged.
  ///
  /// In en, this message translates to:
  /// **'The creation content has changed. Confirm the generation plan again'**
  String get chatTaskInputChanged;

  /// No description provided for @chatTaskConfirmationMismatch.
  ///
  /// In en, this message translates to:
  /// **'The storyboard version does not match the confirmation. Confirm the storyboard again'**
  String get chatTaskConfirmationMismatch;

  /// No description provided for @chatVideoPromptInvalid.
  ///
  /// In en, this message translates to:
  /// **'The generation prompt is invalid. Update the content and confirm again'**
  String get chatVideoPromptInvalid;

  /// No description provided for @chatTaskResultUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The generated result is temporarily unavailable. Please try again later'**
  String get chatTaskResultUnavailable;

  /// No description provided for @chatTaskSubmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'The generation task could not be submitted. Please try again later'**
  String get chatTaskSubmissionFailed;

  /// No description provided for @chatTaskServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The generation service is temporarily unavailable. Please try again later'**
  String get chatTaskServiceUnavailable;

  /// No description provided for @chatRoleReferenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The character reference image is unavailable. Update the image and select the cast again before generating'**
  String get chatRoleReferenceUnavailable;

  /// No description provided for @chatProductionPlan.
  ///
  /// In en, this message translates to:
  /// **'Production plan'**
  String get chatProductionPlan;

  /// No description provided for @chatPlanCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get chatPlanCast;

  /// No description provided for @chatPlanStory.
  ///
  /// In en, this message translates to:
  /// **'Selected story'**
  String get chatPlanStory;

  /// No description provided for @chatPlanHighlight.
  ///
  /// In en, this message translates to:
  /// **'Core highlight'**
  String get chatPlanHighlight;

  /// No description provided for @chatPlanConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Model configuration'**
  String get chatPlanConfiguration;

  /// No description provided for @chatPlanModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatPlanModel;

  /// No description provided for @chatPlanPoints.
  ///
  /// In en, this message translates to:
  /// **'Estimated points'**
  String get chatPlanPoints;

  /// No description provided for @chatPlanCredits.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String chatPlanCredits(String points);

  /// No description provided for @chatReviseContent.
  ///
  /// In en, this message translates to:
  /// **'Revise content'**
  String get chatReviseContent;

  /// No description provided for @chatRevisePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please revise {title}: '**
  String chatRevisePrompt(String title);

  /// No description provided for @chatBeforeChange.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get chatBeforeChange;

  /// No description provided for @chatAfterChange.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get chatAfterChange;

  /// No description provided for @chatCompleteRole.
  ///
  /// In en, this message translates to:
  /// **'Create character'**
  String get chatCompleteRole;

  /// No description provided for @chatConfirmProfileUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update profile'**
  String get chatConfirmProfileUpdate;

  /// No description provided for @chatRoleCreated.
  ///
  /// In en, this message translates to:
  /// **'Character draft created'**
  String get chatRoleCreated;

  /// No description provided for @chatRoleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Character profile updated'**
  String get chatRoleUpdated;

  /// No description provided for @chatRolePublished.
  ///
  /// In en, this message translates to:
  /// **'Character profile published'**
  String get chatRolePublished;

  /// No description provided for @chatViewRoleLibrary.
  ///
  /// In en, this message translates to:
  /// **'View in character library'**
  String get chatViewRoleLibrary;

  /// No description provided for @chatViewRoleProfile.
  ///
  /// In en, this message translates to:
  /// **'View full profile'**
  String get chatViewRoleProfile;

  /// No description provided for @chatCastRole.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get chatCastRole;

  /// No description provided for @chatCastUnmatched.
  ///
  /// In en, this message translates to:
  /// **'Unmatched'**
  String get chatCastUnmatched;

  /// No description provided for @chatCastMultiple.
  ///
  /// In en, this message translates to:
  /// **'{count} roles'**
  String chatCastMultiple(int count);

  /// No description provided for @chatConfirmCast.
  ///
  /// In en, this message translates to:
  /// **'Confirm cast'**
  String get chatConfirmCast;

  /// No description provided for @chatCastRoleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This role is unavailable. Choose a readable role with a saved profile.'**
  String get chatCastRoleUnavailable;

  /// No description provided for @chatRoleActive.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get chatRoleActive;

  /// No description provided for @chatRoleDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get chatRoleDraft;

  /// No description provided for @chatExpandProgress.
  ///
  /// In en, this message translates to:
  /// **'Expand progress'**
  String get chatExpandProgress;

  /// No description provided for @chatCollapseProgress.
  ///
  /// In en, this message translates to:
  /// **'Collapse progress'**
  String get chatCollapseProgress;

  /// No description provided for @chatThoughtProcess.
  ///
  /// In en, this message translates to:
  /// **'Thought process'**
  String get chatThoughtProcess;

  /// No description provided for @chatStepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get chatStepPrepare;

  /// No description provided for @chatStepProcess.
  ///
  /// In en, this message translates to:
  /// **'Process request'**
  String get chatStepProcess;

  /// No description provided for @chatStepReply.
  ///
  /// In en, this message translates to:
  /// **'Generate reply'**
  String get chatStepReply;

  /// No description provided for @chatStepSaveText.
  ///
  /// In en, this message translates to:
  /// **'Save content'**
  String get chatStepSaveText;

  /// No description provided for @chatStepPreparePlan.
  ///
  /// In en, this message translates to:
  /// **'Prepare generation plan'**
  String get chatStepPreparePlan;

  /// No description provided for @chatStepAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze creative requirements'**
  String get chatStepAnalyze;

  /// No description provided for @chatStepReadRole.
  ///
  /// In en, this message translates to:
  /// **'Read character profiles'**
  String get chatStepReadRole;

  /// No description provided for @chatStepReadContext.
  ///
  /// In en, this message translates to:
  /// **'Review creative context'**
  String get chatStepReadContext;

  /// No description provided for @chatStepTopics.
  ///
  /// In en, this message translates to:
  /// **'Suggest topics'**
  String get chatStepTopics;

  /// No description provided for @chatStepPrepareRole.
  ///
  /// In en, this message translates to:
  /// **'Prepare character plan'**
  String get chatStepPrepareRole;

  /// No description provided for @chatStepSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Save character draft'**
  String get chatStepSaveRole;

  /// No description provided for @chatStepPublishRole.
  ///
  /// In en, this message translates to:
  /// **'Publish character'**
  String get chatStepPublishRole;

  /// No description provided for @chatStepVerifyResult.
  ///
  /// In en, this message translates to:
  /// **'Verify results'**
  String get chatStepVerifyResult;

  /// No description provided for @chatStepGenerateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate image'**
  String get chatStepGenerateImage;

  /// No description provided for @chatStepGenerateVideo.
  ///
  /// In en, this message translates to:
  /// **'Generate video'**
  String get chatStepGenerateVideo;

  /// No description provided for @chatStepGenerateAudio.
  ///
  /// In en, this message translates to:
  /// **'Generate audio'**
  String get chatStepGenerateAudio;

  /// No description provided for @chatStepSyncResult.
  ///
  /// In en, this message translates to:
  /// **'Sync results'**
  String get chatStepSyncResult;

  /// No description provided for @chatPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get chatPreparing;

  /// No description provided for @chatProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing your request'**
  String get chatProcessing;

  /// No description provided for @chatGeneratingReply.
  ///
  /// In en, this message translates to:
  /// **'Generating response…'**
  String get chatGeneratingReply;

  /// No description provided for @chatSavingArtifact.
  ///
  /// In en, this message translates to:
  /// **'Saving output…'**
  String get chatSavingArtifact;

  /// No description provided for @chatPlanningGeneration.
  ///
  /// In en, this message translates to:
  /// **'Preparing the generation plan…'**
  String get chatPlanningGeneration;

  /// No description provided for @chatReadRole.
  ///
  /// In en, this message translates to:
  /// **'Reading character profiles'**
  String get chatReadRole;

  /// No description provided for @chatReadContext.
  ///
  /// In en, this message translates to:
  /// **'Reading creation context'**
  String get chatReadContext;

  /// No description provided for @chatTopics.
  ///
  /// In en, this message translates to:
  /// **'Writing story ideas'**
  String get chatTopics;

  /// No description provided for @chatPrepareRole.
  ///
  /// In en, this message translates to:
  /// **'Preparing character creation'**
  String get chatPrepareRole;

  /// No description provided for @redemptionCenter.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get redemptionCenter;

  /// No description provided for @redemptionPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get redemptionPageTitle;

  /// No description provided for @redemptionMyCodes.
  ///
  /// In en, this message translates to:
  /// **'My Invite Codes'**
  String get redemptionMyCodes;

  /// No description provided for @redemptionRegistrationReward.
  ///
  /// In en, this message translates to:
  /// **'Welcome Reward'**
  String get redemptionRegistrationReward;

  /// No description provided for @redemptionInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends, earn points'**
  String get redemptionInviteTitle;

  /// No description provided for @redemptionInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Earn 200 points for each friend\nwho registers and signs in.'**
  String get redemptionInviteDescription;

  /// No description provided for @redemptionRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'A welcome gift from a friend'**
  String get redemptionRewardTitle;

  /// No description provided for @redemptionRewardDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend\'s invite code\nto receive {points} points.'**
  String redemptionRewardDescription(int points);

  /// No description provided for @redemptionPoints.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get redemptionPoints;

  /// No description provided for @redemptionFriendCode.
  ///
  /// In en, this message translates to:
  /// **'Friend\'s Invite Code'**
  String get redemptionFriendCode;

  /// No description provided for @redemptionFriendPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code (once per user)'**
  String get redemptionFriendPlaceholder;

  /// No description provided for @redemptionClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get redemptionClaimed;

  /// No description provided for @redemptionPending.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get redemptionPending;

  /// No description provided for @redemptionUsed.
  ///
  /// In en, this message translates to:
  /// **'Used by a friend'**
  String get redemptionUsed;

  /// No description provided for @redemptionRecords.
  ///
  /// In en, this message translates to:
  /// **'Invitation History'**
  String get redemptionRecords;

  /// No description provided for @redemptionRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get redemptionRegistered;

  /// No description provided for @redemptionCodesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invite codes yet'**
  String get redemptionCodesEmpty;

  /// No description provided for @redemptionRecordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invitations yet'**
  String get redemptionRecordsEmpty;

  /// No description provided for @redemptionFooter.
  ///
  /// In en, this message translates to:
  /// **'Rewards follow the activity rules. Updates may be delayed.'**
  String get redemptionFooter;

  /// No description provided for @redemptionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Please retry.'**
  String get redemptionLoadFailed;

  /// No description provided for @redemptionRewardClosed.
  ///
  /// In en, this message translates to:
  /// **'Welcome rewards are currently unavailable'**
  String get redemptionRewardClosed;

  /// No description provided for @redemptionClaimSuccess.
  ///
  /// In en, this message translates to:
  /// **'Welcome reward claimed'**
  String get redemptionClaimSuccess;

  /// No description provided for @redemptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not redeem. Please try again later.'**
  String get redemptionFailed;

  /// No description provided for @redemptionCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get redemptionCopied;

  /// No description provided for @redemptionLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get redemptionLoadMore;

  /// No description provided for @redemptionLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to invite friends'**
  String get redemptionLoginRequired;

  /// No description provided for @redemptionBindRequired.
  ///
  /// In en, this message translates to:
  /// **'Link WeChat to view invite codes'**
  String get redemptionBindRequired;

  /// No description provided for @redemptionBindAction.
  ///
  /// In en, this message translates to:
  /// **'Link WeChat'**
  String get redemptionBindAction;

  /// No description provided for @redemptionBindDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan with WeChat to link your account'**
  String get redemptionBindDescription;

  /// No description provided for @redemptionQrExpired.
  ///
  /// In en, this message translates to:
  /// **'QR code expired. Please refresh.'**
  String get redemptionQrExpired;

  /// No description provided for @redemptionQrFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load QR code'**
  String get redemptionQrFailed;

  /// No description provided for @redemptionBindingSuccess.
  ///
  /// In en, this message translates to:
  /// **'WeChat linked'**
  String get redemptionBindingSuccess;

  /// No description provided for @redemptionBindingCheck.
  ///
  /// In en, this message translates to:
  /// **'Check link status'**
  String get redemptionBindingCheck;

  /// No description provided for @redemptionBindingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for WeChat scan'**
  String get redemptionBindingWaiting;

  /// No description provided for @teachingAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get teachingAll;

  /// No description provided for @teachingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get teachingCatalog;

  /// No description provided for @teachingRequiredMember.
  ///
  /// In en, this message translates to:
  /// **'membership'**
  String get teachingRequiredMember;

  /// No description provided for @teachingDocumentEmpty.
  ///
  /// In en, this message translates to:
  /// **'This course has no content yet'**
  String get teachingDocumentEmpty;

  /// No description provided for @teachingDocumentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the course content. Please try again'**
  String get teachingDocumentFailed;

  /// No description provided for @teachingReaderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Course reading is unavailable on this platform'**
  String get teachingReaderUnavailable;

  /// No description provided for @teachingCreatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator center'**
  String get teachingCreatorTitle;

  /// No description provided for @teachingCreatorDescription.
  ///
  /// In en, this message translates to:
  /// **'A learning platform\nfor new AI creators'**
  String get teachingCreatorDescription;

  /// No description provided for @teachingCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get teachingCommunityTitle;

  /// No description provided for @teachingCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Meet other creators\nScan to join POPi'**
  String get teachingCommunityDescription;

  /// No description provided for @teachingCommunityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Community QR code unavailable'**
  String get teachingCommunityUnavailable;

  /// No description provided for @teachingMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Member offers'**
  String get teachingMemberTitle;

  /// No description provided for @teachingMemberDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium courses\nExplore more ways to create'**
  String get teachingMemberDescription;

  /// No description provided for @teachingMemberPrice.
  ///
  /// In en, this message translates to:
  /// **'From ¥{price}\nUnlock premium courses'**
  String teachingMemberPrice(String price);

  /// No description provided for @teachingInstructor.
  ///
  /// In en, this message translates to:
  /// **'Tutor: {name}'**
  String teachingInstructor(String name);

  /// No description provided for @teachingFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get teachingFree;

  /// No description provided for @teachingUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled course'**
  String get teachingUntitled;

  /// No description provided for @teachingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading courses'**
  String get teachingLoading;

  /// No description provided for @teachingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No courses available'**
  String get teachingEmpty;

  /// No description provided for @teachingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load courses. Try again later'**
  String get teachingLoadFailed;

  /// No description provided for @teachingLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load more. Tap to retry'**
  String get teachingLoadMoreFailed;

  /// No description provided for @teachingCategoriesFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load categories. Tap to retry'**
  String get teachingCategoriesFailed;

  /// No description provided for @sessionArtifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation Outputs'**
  String get sessionArtifactsTitle;

  /// No description provided for @sessionArtifactAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sessionArtifactAll;

  /// No description provided for @sessionArtifactRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get sessionArtifactRoles;

  /// No description provided for @sessionArtifactScripts.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get sessionArtifactScripts;

  /// No description provided for @sessionArtifactVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get sessionArtifactVideos;

  /// No description provided for @sessionArtifactAudioDetail.
  ///
  /// In en, this message translates to:
  /// **'Audio Details'**
  String get sessionArtifactAudioDetail;

  /// No description provided for @sessionArtifactImageDetail.
  ///
  /// In en, this message translates to:
  /// **'Image Details'**
  String get sessionArtifactImageDetail;

  /// No description provided for @sessionArtifactScriptDetail.
  ///
  /// In en, this message translates to:
  /// **'Script Details'**
  String get sessionArtifactScriptDetail;

  /// No description provided for @sessionArtifactVideoDetail.
  ///
  /// In en, this message translates to:
  /// **'Video Details'**
  String get sessionArtifactVideoDetail;

  /// No description provided for @sessionArtifactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No outputs yet'**
  String get sessionArtifactsEmpty;

  /// No description provided for @chatAskUser.
  ///
  /// In en, this message translates to:
  /// **'Preparing questions'**
  String get chatAskUser;

  /// No description provided for @chatSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Saving character profile'**
  String get chatSaveRole;

  /// No description provided for @chatPublishRole.
  ///
  /// In en, this message translates to:
  /// **'Preparing character publication'**
  String get chatPublishRole;

  /// No description provided for @chatPreviewImage.
  ///
  /// In en, this message translates to:
  /// **'Preview image'**
  String get chatPreviewImage;

  /// No description provided for @chatCollapseProfile.
  ///
  /// In en, this message translates to:
  /// **'Collapse profile'**
  String get chatCollapseProfile;

  /// No description provided for @chatConfirmGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get chatConfirmGeneration;

  /// No description provided for @generationCreditNotice.
  ///
  /// In en, this message translates to:
  /// **'Please note: Clicking \"Generate\" will deduct the corresponding points. Points already consumed are non-refundable. Please carefully review your materials, prompts, and generation settings before submitting.'**
  String get generationCreditNotice;

  /// No description provided for @generationCreditNoticeNonRefundable.
  ///
  /// In en, this message translates to:
  /// **'Points already consumed are non-refundable'**
  String get generationCreditNoticeNonRefundable;

  /// No description provided for @chatRoleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chatRoleName;

  /// No description provided for @chatReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Reconnecting…'**
  String get chatReconnecting;

  /// No description provided for @chatRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed. Please try again'**
  String get chatRequestFailed;

  /// No description provided for @chatInsufficientPoints.
  ///
  /// In en, this message translates to:
  /// **'Not enough points. Top up and try again'**
  String get chatInsufficientPoints;

  /// No description provided for @chatRunFailed.
  ///
  /// In en, this message translates to:
  /// **'This request failed'**
  String get chatRunFailed;

  /// No description provided for @chatStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get chatStopped;

  /// No description provided for @chatCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatCompleted;

  /// No description provided for @chatTextTopic.
  ///
  /// In en, this message translates to:
  /// **'Story idea'**
  String get chatTextTopic;

  /// No description provided for @chatTextScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get chatTextScript;

  /// No description provided for @chatTextStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Storyboard prompt'**
  String get chatTextStoryboard;

  /// No description provided for @chatTextUnknownDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration not recorded'**
  String get chatTextUnknownDuration;

  /// No description provided for @chatProgressDetails.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get chatProgressDetails;

  /// No description provided for @chatProgressPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get chatProgressPending;

  /// No description provided for @chatProgressRunning.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get chatProgressRunning;

  /// No description provided for @chatProgressWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get chatProgressWaiting;

  /// No description provided for @chatProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get chatProgressFailed;

  /// No description provided for @chatProgressCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get chatProgressCompleted;

  /// No description provided for @chatProgressRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get chatProgressRunFailed;

  /// No description provided for @chatProgressStopped.
  ///
  /// In en, this message translates to:
  /// **'Reply stopped'**
  String get chatProgressStopped;

  /// No description provided for @chatProgressPrepare.
  ///
  /// In en, this message translates to:
  /// **'Preparing context'**
  String get chatProgressPrepare;

  /// No description provided for @chatProgressReply.
  ///
  /// In en, this message translates to:
  /// **'Composing reply'**
  String get chatProgressReply;

  /// No description provided for @chatProgressSaveText.
  ///
  /// In en, this message translates to:
  /// **'Saving written content'**
  String get chatProgressSaveText;

  /// No description provided for @chatProgressPreparePlan.
  ///
  /// In en, this message translates to:
  /// **'Preparing generation plan'**
  String get chatProgressPreparePlan;

  /// No description provided for @chatProgressUpdateRole.
  ///
  /// In en, this message translates to:
  /// **'Updating character'**
  String get chatProgressUpdateRole;

  /// No description provided for @chatProgressProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get chatProgressProcessing;

  /// No description provided for @chatProgressUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding your request…'**
  String get chatProgressUnderstanding;

  /// No description provided for @chatProgressSelectingSkill.
  ///
  /// In en, this message translates to:
  /// **'Selecting a creative skill…'**
  String get chatProgressSelectingSkill;

  /// No description provided for @chatProgressReadingRules.
  ///
  /// In en, this message translates to:
  /// **'Reading creative guidelines…'**
  String get chatProgressReadingRules;

  /// No description provided for @chatProgressComposing.
  ///
  /// In en, this message translates to:
  /// **'Planning the response…'**
  String get chatProgressComposing;

  /// No description provided for @chatProgressPreparingGeneration.
  ///
  /// In en, this message translates to:
  /// **'Preparing the generation task…'**
  String get chatProgressPreparingGeneration;

  /// No description provided for @chatProgressGeneratingArtifact.
  ///
  /// In en, this message translates to:
  /// **'Generating content…'**
  String get chatProgressGeneratingArtifact;

  /// No description provided for @chatProgressCompletingDelivery.
  ///
  /// In en, this message translates to:
  /// **'Output generated. Finishing delivery…'**
  String get chatProgressCompletingDelivery;

  /// No description provided for @chatProgressWaitingInput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your input…'**
  String get chatProgressWaitingInput;

  /// No description provided for @chatProgressAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your request'**
  String get chatProgressAnalyze;

  /// No description provided for @chatProgressExecuteTool.
  ///
  /// In en, this message translates to:
  /// **'Performing operation'**
  String get chatProgressExecuteTool;

  /// No description provided for @chatProgressLoadSkill.
  ///
  /// In en, this message translates to:
  /// **'Loading creative guidance'**
  String get chatProgressLoadSkill;

  /// No description provided for @chatProgressSkillTopics.
  ///
  /// In en, this message translates to:
  /// **'Loading story guidance'**
  String get chatProgressSkillTopics;

  /// No description provided for @chatProgressSkillScript.
  ///
  /// In en, this message translates to:
  /// **'Loading script guidance'**
  String get chatProgressSkillScript;

  /// No description provided for @chatProgressSkillStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Loading storyboard guidance'**
  String get chatProgressSkillStoryboard;

  /// No description provided for @chatProgressSkillThreeView.
  ///
  /// In en, this message translates to:
  /// **'Loading character sheet guidance'**
  String get chatProgressSkillThreeView;

  /// No description provided for @chatProgressWriteScript.
  ///
  /// In en, this message translates to:
  /// **'Writing script'**
  String get chatProgressWriteScript;

  /// No description provided for @chatProgressWriteStoryboard.
  ///
  /// In en, this message translates to:
  /// **'Writing storyboard and video prompt'**
  String get chatProgressWriteStoryboard;

  /// No description provided for @chatProgressReadTextSources.
  ///
  /// In en, this message translates to:
  /// **'Reading source text and requirements'**
  String get chatProgressReadTextSources;

  /// No description provided for @chatProgressValidateText.
  ///
  /// In en, this message translates to:
  /// **'Checking content, duration and structure'**
  String get chatProgressValidateText;

  /// No description provided for @chatProgressReadText.
  ///
  /// In en, this message translates to:
  /// **'Reading written content'**
  String get chatProgressReadText;

  /// No description provided for @chatProgressSearchRoles.
  ///
  /// In en, this message translates to:
  /// **'Finding characters'**
  String get chatProgressSearchRoles;

  /// No description provided for @chatProgressCreateRole.
  ///
  /// In en, this message translates to:
  /// **'Creating character'**
  String get chatProgressCreateRole;

  /// No description provided for @chatProgressCopyRole.
  ///
  /// In en, this message translates to:
  /// **'Preparing personal character copy'**
  String get chatProgressCopyRole;

  /// No description provided for @chatProgressAdoptRoleImage.
  ///
  /// In en, this message translates to:
  /// **'Saving selected character image'**
  String get chatProgressAdoptRoleImage;

  /// No description provided for @chatProgressReadAccount.
  ///
  /// In en, this message translates to:
  /// **'Reading account profile'**
  String get chatProgressReadAccount;

  /// No description provided for @chatProgressSearchAccounts.
  ///
  /// In en, this message translates to:
  /// **'Finding accounts'**
  String get chatProgressSearchAccounts;

  /// No description provided for @chatProgressSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Loading selected account'**
  String get chatProgressSelectAccount;

  /// No description provided for @chatProgressUpdateAccount.
  ///
  /// In en, this message translates to:
  /// **'Updating account preferences'**
  String get chatProgressUpdateAccount;

  /// No description provided for @chatProgressUpdateMemory.
  ///
  /// In en, this message translates to:
  /// **'Updating account memory'**
  String get chatProgressUpdateMemory;

  /// No description provided for @chatProgressSearchCreations.
  ///
  /// In en, this message translates to:
  /// **'Finding previous creations'**
  String get chatProgressSearchCreations;

  /// No description provided for @chatProgressReadCreation.
  ///
  /// In en, this message translates to:
  /// **'Reading previous creation'**
  String get chatProgressReadCreation;

  /// No description provided for @chatProgressReadTemplates.
  ///
  /// In en, this message translates to:
  /// **'Reading style templates'**
  String get chatProgressReadTemplates;

  /// No description provided for @chatProgressReadReferences.
  ///
  /// In en, this message translates to:
  /// **'Preparing references'**
  String get chatProgressReadReferences;

  /// No description provided for @chatProgressValidatePlan.
  ///
  /// In en, this message translates to:
  /// **'Checking model capabilities and parameters'**
  String get chatProgressValidatePlan;

  /// No description provided for @chatProgressEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimating credits'**
  String get chatProgressEstimate;

  /// No description provided for @chatProgressVerifyResult.
  ///
  /// In en, this message translates to:
  /// **'Verifying operation result'**
  String get chatProgressVerifyResult;

  /// No description provided for @chatProgressCompilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Writing image prompt'**
  String get chatProgressCompilePrompt;

  /// No description provided for @chatProgressValidatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Checking image prompt'**
  String get chatProgressValidatePrompt;

  /// No description provided for @chatProgressSavePrompt.
  ///
  /// In en, this message translates to:
  /// **'Saving image prompt'**
  String get chatProgressSavePrompt;

  /// No description provided for @chatProgressRetryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt compilation interrupted; awaiting retry'**
  String get chatProgressRetryPrompt;

  /// No description provided for @chatProgressSubmitGeneration.
  ///
  /// In en, this message translates to:
  /// **'Submitting generation task'**
  String get chatProgressSubmitGeneration;

  /// No description provided for @chatProgressQueuedGeneration.
  ///
  /// In en, this message translates to:
  /// **'Queued for generation'**
  String get chatProgressQueuedGeneration;

  /// No description provided for @chatProgressGenerateImage.
  ///
  /// In en, this message translates to:
  /// **'Generating image'**
  String get chatProgressGenerateImage;

  /// No description provided for @chatProgressGenerateVideo.
  ///
  /// In en, this message translates to:
  /// **'Generating video'**
  String get chatProgressGenerateVideo;

  /// No description provided for @chatProgressGenerateAudio.
  ///
  /// In en, this message translates to:
  /// **'Generating audio'**
  String get chatProgressGenerateAudio;

  /// No description provided for @chatProgressSaveMedia.
  ///
  /// In en, this message translates to:
  /// **'Saving generated result'**
  String get chatProgressSaveMedia;

  /// No description provided for @chatProgressSyncResult.
  ///
  /// In en, this message translates to:
  /// **'Retrying result synchronization'**
  String get chatProgressSyncResult;

  /// No description provided for @chatExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get chatExpired;

  /// No description provided for @chatAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get chatAwaitingConfirmation;

  /// No description provided for @chatStop.
  ///
  /// In en, this message translates to:
  /// **'Stop reply'**
  String get chatStop;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get chatSending;

  /// No description provided for @chatPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get chatPlayVideo;

  /// No description provided for @chatPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get chatPlayAudio;

  /// No description provided for @chatCustomAnswer.
  ///
  /// In en, this message translates to:
  /// **'Add your own answer'**
  String get chatCustomAnswer;

  /// No description provided for @chatMediaPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please use these images as references'**
  String get chatMediaPrompt;

  /// No description provided for @chatHistoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load conversations'**
  String get chatHistoryLoadFailed;

  /// No description provided for @chatEstimatedPoints.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost: {points} points'**
  String chatEstimatedPoints(String points);

  /// No description provided for @demoConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get demoConversations;

  /// No description provided for @demoAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get demoAssets;

  /// No description provided for @demoSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get demoSearchHistory;

  /// No description provided for @demoSearchAssets.
  ///
  /// In en, this message translates to:
  /// **'Search assets'**
  String get demoSearchAssets;

  /// No description provided for @demoProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get demoProject;

  /// No description provided for @demoConversation.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get demoConversation;

  /// No description provided for @demoWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get demoWorkflow;

  /// No description provided for @demoNew.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get demoNew;

  /// No description provided for @demoSettings.
  ///
  /// In en, this message translates to:
  /// **'Conversation settings'**
  String get demoSettings;

  /// No description provided for @demoInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get demoInfo;

  /// No description provided for @demoCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get demoCapabilities;

  /// No description provided for @demoOutputs.
  ///
  /// In en, this message translates to:
  /// **'Outputs'**
  String get demoOutputs;

  /// No description provided for @demoLinkedRoles.
  ///
  /// In en, this message translates to:
  /// **'Linked characters'**
  String get demoLinkedRoles;

  /// No description provided for @demoAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get demoAddMembers;

  /// No description provided for @demoMemberProfile.
  ///
  /// In en, this message translates to:
  /// **'Assistant profile'**
  String get demoMemberProfile;

  /// No description provided for @demoRoleProfile.
  ///
  /// In en, this message translates to:
  /// **'Character profile'**
  String get demoRoleProfile;

  /// No description provided for @demoPopi.
  ///
  /// In en, this message translates to:
  /// **'POPi'**
  String get demoPopi;

  /// No description provided for @demoDesigner.
  ///
  /// In en, this message translates to:
  /// **'Character designer'**
  String get demoDesigner;

  /// No description provided for @demoWriter.
  ///
  /// In en, this message translates to:
  /// **'Script writer'**
  String get demoWriter;

  /// No description provided for @demoDirector.
  ///
  /// In en, this message translates to:
  /// **'Film director'**
  String get demoDirector;

  /// No description provided for @demoSound.
  ///
  /// In en, this message translates to:
  /// **'Sound creator'**
  String get demoSound;

  /// No description provided for @demoPopiDescription.
  ///
  /// In en, this message translates to:
  /// **'A creative assistant for images, stories and video'**
  String get demoPopiDescription;

  /// No description provided for @demoDesignerDescription.
  ///
  /// In en, this message translates to:
  /// **'Create characters and scene images'**
  String get demoDesignerDescription;

  /// No description provided for @demoWriterDescription.
  ///
  /// In en, this message translates to:
  /// **'Turn ideas into scripts and storyboards'**
  String get demoWriterDescription;

  /// No description provided for @demoDirectorDescription.
  ///
  /// In en, this message translates to:
  /// **'Create moving images and finished videos'**
  String get demoDirectorDescription;

  /// No description provided for @demoSoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Create voices, music and sound effects'**
  String get demoSoundDescription;

  /// No description provided for @demoRename.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get demoRename;

  /// No description provided for @demoName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get demoName;

  /// No description provided for @demoPreferences.
  ///
  /// In en, this message translates to:
  /// **'Account preferences'**
  String get demoPreferences;

  /// No description provided for @demoDirection.
  ///
  /// In en, this message translates to:
  /// **'Content direction'**
  String get demoDirection;

  /// No description provided for @demoFeeling.
  ///
  /// In en, this message translates to:
  /// **'Audience feeling'**
  String get demoFeeling;

  /// No description provided for @demoFeelingValue.
  ///
  /// In en, this message translates to:
  /// **'Authentic, with a little tenderness'**
  String get demoFeelingValue;

  /// No description provided for @demoFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get demoFormat;

  /// No description provided for @demoFormatValue.
  ///
  /// In en, this message translates to:
  /// **'AI realism × short stories'**
  String get demoFormatValue;

  /// No description provided for @demoAudience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get demoAudience;

  /// No description provided for @demoAudienceValue.
  ///
  /// In en, this message translates to:
  /// **'Students and working professionals'**
  String get demoAudienceValue;

  /// No description provided for @demoPositioning.
  ///
  /// In en, this message translates to:
  /// **'Account positioning'**
  String get demoPositioning;

  /// No description provided for @demoCharacterSkill.
  ///
  /// In en, this message translates to:
  /// **'Character settings'**
  String get demoCharacterSkill;

  /// No description provided for @demoScriptSkill.
  ///
  /// In en, this message translates to:
  /// **'Scripts and storyboards'**
  String get demoScriptSkill;

  /// No description provided for @demoImageSkill.
  ///
  /// In en, this message translates to:
  /// **'Image generation'**
  String get demoImageSkill;

  /// No description provided for @demoVideoSkill.
  ///
  /// In en, this message translates to:
  /// **'Video generation'**
  String get demoVideoSkill;

  /// No description provided for @demoAudioSkill.
  ///
  /// In en, this message translates to:
  /// **'Audio generation'**
  String get demoAudioSkill;

  /// No description provided for @demoEnabledHere.
  ///
  /// In en, this message translates to:
  /// **'Enabled in this conversation'**
  String get demoEnabledHere;

  /// No description provided for @demoWorkMode.
  ///
  /// In en, this message translates to:
  /// **'Working mode'**
  String get demoWorkMode;

  /// No description provided for @demoOnDemand.
  ///
  /// In en, this message translates to:
  /// **'On demand'**
  String get demoOnDemand;

  /// No description provided for @demoOfficialRoles.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get demoOfficialRoles;

  /// No description provided for @demoMyRoles.
  ///
  /// In en, this message translates to:
  /// **'My characters'**
  String get demoMyRoles;

  /// No description provided for @demoCreateRole.
  ///
  /// In en, this message translates to:
  /// **'Create character'**
  String get demoCreateRole;

  /// No description provided for @demoJoin.
  ///
  /// In en, this message translates to:
  /// **'Join creation'**
  String get demoJoin;

  /// No description provided for @demoNoRoles.
  ///
  /// In en, this message translates to:
  /// **'No linked characters'**
  String get demoNoRoles;

  /// No description provided for @demoNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get demoNoResults;

  /// No description provided for @demoEmptyAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets yet'**
  String get demoEmptyAssets;

  /// No description provided for @demoEmptyConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get demoEmptyConversations;

  /// No description provided for @demoAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get demoAll;

  /// No description provided for @demoImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get demoImages;

  /// No description provided for @demoVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get demoVideos;

  /// No description provided for @demoScripts.
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get demoScripts;

  /// No description provided for @demoAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get demoAudio;

  /// No description provided for @demoUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload material'**
  String get demoUpload;

  /// No description provided for @demoSampleLibrary.
  ///
  /// In en, this message translates to:
  /// **'Material library'**
  String get demoSampleLibrary;

  /// No description provided for @demoImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get demoImport;

  /// No description provided for @demoImported.
  ///
  /// In en, this message translates to:
  /// **'Material added to your library'**
  String get demoImported;

  /// No description provided for @demoAssetDetails.
  ///
  /// In en, this message translates to:
  /// **'Asset details'**
  String get demoAssetDetails;

  /// No description provided for @demoRenameAsset.
  ///
  /// In en, this message translates to:
  /// **'Rename asset'**
  String get demoRenameAsset;

  /// No description provided for @demoAudioDetails.
  ///
  /// In en, this message translates to:
  /// **'Audio details'**
  String get demoAudioDetails;

  /// No description provided for @demoAudioBackward.
  ///
  /// In en, this message translates to:
  /// **'Back 15 seconds'**
  String get demoAudioBackward;

  /// No description provided for @demoAudioForward.
  ///
  /// In en, this message translates to:
  /// **'Forward 15 seconds'**
  String get demoAudioForward;

  /// No description provided for @demoGenerated.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get demoGenerated;

  /// No description provided for @demoComposer.
  ///
  /// In en, this message translates to:
  /// **'Say something to POPi…'**
  String get demoComposer;

  /// No description provided for @v2CreatePopi.
  ///
  /// In en, this message translates to:
  /// **'Create a POPi'**
  String get v2CreatePopi;

  /// No description provided for @v2PopiPersonality.
  ///
  /// In en, this message translates to:
  /// **'Responsibilities & personality'**
  String get v2PopiPersonality;

  /// No description provided for @v2PopiPersonalityHint.
  ///
  /// In en, this message translates to:
  /// **'Describe POPi\'s role, tone and collaboration preferences (optional)'**
  String get v2PopiPersonalityHint;

  /// No description provided for @v2MyColor.
  ///
  /// In en, this message translates to:
  /// **'My color'**
  String get v2MyColor;

  /// No description provided for @v2AddCreativeRole.
  ///
  /// In en, this message translates to:
  /// **'Add your creative character'**
  String get v2AddCreativeRole;

  /// No description provided for @v2AddCreativeRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'Link an existing character or upload your own DIY character reference so your assistant knows who you\'re creating with.'**
  String get v2AddCreativeRoleDescription;

  /// No description provided for @v2CreateDiyRole.
  ///
  /// In en, this message translates to:
  /// **'Create DIY character'**
  String get v2CreateDiyRole;

  /// No description provided for @demoGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi there'**
  String get demoGreeting;

  /// No description provided for @demoGreetingDetail.
  ///
  /// In en, this message translates to:
  /// **'What would you like to create?'**
  String get demoGreetingDetail;

  /// No description provided for @demoDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated results may contain errors'**
  String get demoDisclaimer;

  /// No description provided for @demoThinking.
  ///
  /// In en, this message translates to:
  /// **'POPi is thinking…'**
  String get demoThinking;

  /// No description provided for @demoVoice.
  ///
  /// In en, this message translates to:
  /// **'Let Alice meet an old friend at a cafe.'**
  String get demoVoice;

  /// No description provided for @demoQuickImage.
  ///
  /// In en, this message translates to:
  /// **'Generate five scene images'**
  String get demoQuickImage;

  /// No description provided for @demoQuickScript.
  ///
  /// In en, this message translates to:
  /// **'Write a reunion script'**
  String get demoQuickScript;

  /// No description provided for @demoQuickVideo.
  ///
  /// In en, this message translates to:
  /// **'Create a weekend video'**
  String get demoQuickVideo;

  /// No description provided for @demoQuickAudio.
  ///
  /// In en, this message translates to:
  /// **'Create afternoon music'**
  String get demoQuickAudio;

  /// No description provided for @demoReply.
  ///
  /// In en, this message translates to:
  /// **'This could become a warm short film.\\n\\n**Three ideas**\\n1. An unexpected reunion at a cafe\\n2. Walking home before graduation\\n3. A letter that arrived years late\\n\\nWhich shall we develop?'**
  String get demoReply;

  /// No description provided for @demoImageReply.
  ///
  /// In en, this message translates to:
  /// **'Your scene images are ready. How do you like this look?'**
  String get demoImageReply;

  /// No description provided for @demoScriptReply.
  ///
  /// In en, this message translates to:
  /// **'Your script and storyboard are ready.'**
  String get demoScriptReply;

  /// No description provided for @demoAudioReply.
  ///
  /// In en, this message translates to:
  /// **'Your afternoon music is ready.'**
  String get demoAudioReply;

  /// No description provided for @demoVideoReply.
  ///
  /// In en, this message translates to:
  /// **'Your weekend video is ready.'**
  String get demoVideoReply;

  /// No description provided for @demoWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, creator'**
  String get demoWelcomeTitle;

  /// No description provided for @demoWelcomeCopy.
  ///
  /// In en, this message translates to:
  /// **'Before we begin,\ntell me what you\nwould like to create.'**
  String get demoWelcomeCopy;

  /// No description provided for @demoStartIp.
  ///
  /// In en, this message translates to:
  /// **'Create a new IP account'**
  String get demoStartIp;

  /// No description provided for @demoStartRole.
  ///
  /// In en, this message translates to:
  /// **'Start with a character'**
  String get demoStartRole;

  /// No description provided for @demoStartIdea.
  ///
  /// In en, this message translates to:
  /// **'Start with an idea'**
  String get demoStartIdea;

  /// No description provided for @demoStartChat.
  ///
  /// In en, this message translates to:
  /// **'Let\'s chat first'**
  String get demoStartChat;

  /// No description provided for @demoReset.
  ///
  /// In en, this message translates to:
  /// **'Reset demo data'**
  String get demoReset;

  /// No description provided for @demoResetDescription.
  ///
  /// In en, this message translates to:
  /// **'Restore the original conversations and assets and clear your demo edits?'**
  String get demoResetDescription;

  /// No description provided for @demoResetDone.
  ///
  /// In en, this message translates to:
  /// **'Demo data restored'**
  String get demoResetDone;

  /// No description provided for @demoStorageError.
  ///
  /// In en, this message translates to:
  /// **'Could not save locally. Please try again.'**
  String get demoStorageError;

  /// No description provided for @demoDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get demoDeleteDescription;

  /// No description provided for @demoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get demoUpdated;

  /// No description provided for @demoNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get demoNow;

  /// No description provided for @demoPlayback.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get demoPlayback;

  /// No description provided for @demoPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get demoPause;

  /// No description provided for @demoSeek.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get demoSeek;

  /// No description provided for @demoReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get demoReplay;

  /// No description provided for @demoReference.
  ///
  /// In en, this message translates to:
  /// **'Image / Reference'**
  String get demoReference;

  /// No description provided for @demoImageMeta.
  ///
  /// In en, this message translates to:
  /// **'Image / 9:16'**
  String get demoImageMeta;

  /// No description provided for @demoScriptMeta.
  ///
  /// In en, this message translates to:
  /// **'Script/MD'**
  String get demoScriptMeta;

  /// No description provided for @demoAudioMeta.
  ///
  /// In en, this message translates to:
  /// **'Audio/00:24'**
  String get demoAudioMeta;

  /// No description provided for @demoVideoMeta.
  ///
  /// In en, this message translates to:
  /// **'Video / 00:08'**
  String get demoVideoMeta;

  /// No description provided for @demoAttachments.
  ///
  /// In en, this message translates to:
  /// **'Add material'**
  String get demoAttachments;

  /// No description provided for @demoRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove material'**
  String get demoRemoveAttachment;

  /// No description provided for @demoChoose.
  ///
  /// In en, this message translates to:
  /// **'Select members'**
  String get demoChoose;

  /// No description provided for @demoProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get demoProfile;

  /// No description provided for @demoMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get demoMembers;

  /// No description provided for @demoRoleBio.
  ///
  /// In en, this message translates to:
  /// **'Loves life and turns everyday moments into warm stories.'**
  String get demoRoleBio;

  /// No description provided for @demoAddSkill.
  ///
  /// In en, this message translates to:
  /// **'Add a skill'**
  String get demoAddSkill;

  /// No description provided for @demoGenerating.
  ///
  /// In en, this message translates to:
  /// **'Creating'**
  String get demoGenerating;

  /// No description provided for @demoNewRoleName.
  ///
  /// In en, this message translates to:
  /// **'Character name'**
  String get demoNewRoleName;

  /// No description provided for @demoSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get demoSend;

  /// No description provided for @demoSessionName.
  ///
  /// In en, this message translates to:
  /// **'Conversation name'**
  String get demoSessionName;

  /// No description provided for @demoRoleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String demoRoleCount(int count);

  /// No description provided for @demoSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count}/{total}'**
  String demoSelectedCount(int count, int total);

  /// No description provided for @demoSelectMembers.
  ///
  /// In en, this message translates to:
  /// **'Select members'**
  String get demoSelectMembers;

  /// No description provided for @demoEditMember.
  ///
  /// In en, this message translates to:
  /// **'Edit member'**
  String get demoEditMember;

  /// No description provided for @demoMyName.
  ///
  /// In en, this message translates to:
  /// **'My name'**
  String get demoMyName;

  /// No description provided for @demoMyAppearance.
  ///
  /// In en, this message translates to:
  /// **'My appearance'**
  String get demoMyAppearance;

  /// No description provided for @demoRandomAppearance.
  ///
  /// In en, this message translates to:
  /// **'Suggest another'**
  String get demoRandomAppearance;

  /// No description provided for @demoAvatarNumber.
  ///
  /// In en, this message translates to:
  /// **'Avatar {number}'**
  String demoAvatarNumber(int number);

  /// No description provided for @demoBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get demoBackgroundColor;

  /// No description provided for @demoProfileLink.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get demoProfileLink;

  /// No description provided for @demoEnabledItems.
  ///
  /// In en, this message translates to:
  /// **'Enabled skills'**
  String get demoEnabledItems;

  /// No description provided for @demoCharacterDetail.
  ///
  /// In en, this message translates to:
  /// **'Keep the character identity and look'**
  String get demoCharacterDetail;

  /// No description provided for @demoScriptDetail.
  ///
  /// In en, this message translates to:
  /// **'Turn ideas into a complete plan'**
  String get demoScriptDetail;

  /// No description provided for @demoImageDetail.
  ///
  /// In en, this message translates to:
  /// **'Create character and scene images'**
  String get demoImageDetail;

  /// No description provided for @demoVideoDetail.
  ///
  /// In en, this message translates to:
  /// **'Create videos ready to publish'**
  String get demoVideoDetail;

  /// No description provided for @demoAudioDetail.
  ///
  /// In en, this message translates to:
  /// **'Create voices, music and sound effects'**
  String get demoAudioDetail;

  /// No description provided for @demoUploadLibrary.
  ///
  /// In en, this message translates to:
  /// **'Upload to asset library'**
  String get demoUploadLibrary;

  /// No description provided for @demoSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get demoSelectFiles;

  /// No description provided for @demoFileTypes.
  ///
  /// In en, this message translates to:
  /// **'Images, videos, scripts, audio'**
  String get demoFileTypes;

  /// No description provided for @demoSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files selected'**
  String demoSelectedFiles(int count);
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
