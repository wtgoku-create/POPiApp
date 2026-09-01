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
}
