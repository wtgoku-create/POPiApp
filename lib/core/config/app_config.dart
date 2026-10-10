abstract final class AppConfig {
  // Defaults preserve plain flutter run; environment files override these at build time.
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://wwwtest.popi.art',
  );
  static const enableApiLogging = bool.fromEnvironment(
    'API_ENABLE_LOGGING',
    defaultValue: false,
  );
  static const teachingCenterUrl = String.fromEnvironment(
    'TEACHING_CENTER_URL',
    defaultValue: '$apiBaseUrl/teaching',
  );
  static const teachingReaderUrl = String.fromEnvironment(
    'TEACHING_READER_URL',
    defaultValue: '$teachingCenterUrl/reader',
  );
  static const applePaymentEnvironment = String.fromEnvironment(
    'APPLE_PAYMENT_ENVIRONMENT',
    defaultValue: 'Production',
  );
  static const agentApiBaseUrl = String.fromEnvironment(
    'AGENT_API_BASE_URL',
    defaultValue: apiBaseUrl,
  );
  static const agentApiOrigin = String.fromEnvironment('AGENT_API_ORIGIN');
  static const wechatAppId = String.fromEnvironment(
    'WECHAT_APP_ID',
    defaultValue: 'wxf99ad5d5c7b4fe37',
  );
  static const wechatUniversalLink = String.fromEnvironment(
    'WECHAT_UNIVERSAL_LINK',
    defaultValue: 'https://app.popi.art/WeChat/',
  );
  static const douyinClientKey = String.fromEnvironment(
    'DOUYIN_CLIENT_KEY',
    defaultValue: 'awrmmvudt93mnhxg',
  );
  static const douyinUniversalLink = String.fromEnvironment(
    'DOUYIN_UNIVERSAL_LINK',
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
