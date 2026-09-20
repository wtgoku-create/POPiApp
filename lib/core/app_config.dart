import 'package:flutter/services.dart';

enum AppBrand { popi, popistudio }

class AppConfig {
  const AppConfig(this.brand);
  final AppBrand brand;
  static AppConfig get current => fromFlavor(appFlavor);
  static AppConfig fromFlavor(String? flavor) => switch (flavor) {
        null || 'popi' => const AppConfig(AppBrand.popi),
        'popistudio' => const AppConfig(AppBrand.popistudio),
        _ => throw StateError('Unknown app flavor: $flavor'),
      };
  String get bundleId =>
      brand == AppBrand.popi ? 'com.popiai.app' : 'com.popistudio.app';
  String get productPrefix => brand.name;
  String get displayName => brand == AppBrand.popi ? 'POPi AI' : 'POPi Studio';
  String get wechatAppId =>
      brand == AppBrand.popi ? 'wxf99ad5d5c7b4fe37' : 'wx0d9c23195606fc80';
  String get wechatUniversalLink => 'https://app.popi.art/WeChat/';
  bool get wechatEnabled => wechatAppId.isNotEmpty;
}
