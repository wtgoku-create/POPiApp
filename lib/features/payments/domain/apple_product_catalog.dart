import '../../../core/app_config.dart';

const appleMembershipType = 'nonRenewingSubscription';
const appleConsumableType = 'consumable';
const appleCreditSuffixes = {
  'credits.600',
  'credits.1000',
  'credits.2000',
  'credits.6000',
  'credits.10000',
  'credits.20000'
};
const appleMembershipSuffixes = {
  'max.36500.monthly',
  'pro.28000.monthly',
  'plus.14400.monthly',
  'plus.5500.monthly',
  'starter.1750.monthly'
};

String resolveAppleProductId(String configuredProductId,
    {AppConfig? config, bool consumable = false}) {
  final app = config ?? AppConfig.current;
  final id = configuredProductId.trim();
  final suffixes = consumable ? appleCreditSuffixes : appleMembershipSuffixes;
  return suffixes.any((suffix) => id == '${app.productPrefix}.$suffix')
      ? id
      : '';
}

String? appleProductType(String id, {AppConfig? config}) {
  if (resolveAppleProductId(id, config: config, consumable: true).isNotEmpty) {
    return appleConsumableType;
  }
  if (resolveAppleProductId(id, config: config).isNotEmpty) {
    return appleMembershipType;
  }
  return null;
}
