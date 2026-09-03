const appleTestProductId = 'popi.membership.starter.30d';
const appleTestProductType = 'nonRenewingSubscription';

// Keep every purchase entry on the single App Store sandbox product during
// integration testing. Replace this with the backend value before release.
String resolveAppleProductId(String configuredProductId) => appleTestProductId;
