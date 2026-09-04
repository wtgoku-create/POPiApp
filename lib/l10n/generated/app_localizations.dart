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
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'POPi'**
  String get appTitle;

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

  /// No description provided for @graphicalCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Image verification'**
  String get graphicalCaptcha;

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

  /// No description provided for @loginAgreement.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the User Agreement and Privacy Policy'**
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

  /// No description provided for @homeGreetingBody.
  ///
  /// In en, this message translates to:
  /// **'I\'ll help you\nbuild an account together!'**
  String get homeGreetingBody;

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

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutDescription.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to continue using POPi'**
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
  /// **'Note: Membership is required for member characters, watermark-free images and videos, and other benefits. Buying points alone does not include these benefits. Purchased points are valid for one year. If you have any questions, please contact customer service.'**
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
      'that was used.');
}
