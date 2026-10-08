/// Display data for an IP account, independent of its eventual API payload.
class IpAccount {
  const IpAccount({
    required this.id,
    required this.title,
    required this.description,
    this.isPaused = false,
    this.isRecentlyUsed = false,
  });

  final String id;
  final String title;
  final String description;
  final bool isPaused;
  final bool isRecentlyUsed;
}
