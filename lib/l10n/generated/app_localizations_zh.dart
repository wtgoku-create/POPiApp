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
  String get english => '英文';

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
}
