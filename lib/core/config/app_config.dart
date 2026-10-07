abstract final class AppConfig {
  // Defaults preserve plain flutter run; environment files override these at build time.
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const passwordLoginEnabled =
      environment == 'development' || environment == 'dev';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://wwwtest.popi.art',
  );
  static const enableApiLogging = bool.fromEnvironment(
    'API_ENABLE_LOGGING',
    defaultValue: false,
  );
  static const wechatAppId = String.fromEnvironment(
    'WECHAT_APP_ID',
    defaultValue: 'wxf99ad5d5c7b4fe37',
  );
  static const wechatUniversalLink = String.fromEnvironment(
    'WECHAT_UNIVERSAL_LINK',
    defaultValue: 'https://app.popi.art/WeChat/',
  );
  static const userAgreementUrl = String.fromEnvironment(
    'USER_AGREEMENT_URL',
    defaultValue:
        'https://tcnshqo5yu6i.feishu.cn/wiki/BmCNwr8o0ii19dkcTYAcaW9Jnhc',
  );
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue:
        'https://tcnshqo5yu6i.feishu.cn/wiki/Wu8mwLqOYi2nZjkur3rc18wFnbg',
  );
}
