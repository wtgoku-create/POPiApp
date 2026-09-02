import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../data/point_package_repository.dart';
import '../data/user_points_log_repository.dart';
import '../domain/point_package.dart';
import '../domain/user_points_log.dart';

typedef PointsLogPageLoader = Future<UserPointsLogPage> Function(
  int page,
  int pageSize,
);
typedef PointPackageLoader = Future<List<PointPackage>> Function();

Future<PointPackage?> showRechargePointsSheet({
  required BuildContext context,
  required int totalPoints,
  required PointPackageLoader loadPackages,
}) {
  return AppSheet.show<PointPackage>(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x33333333),
    builder: (context) => _RechargePointsSheet(
      totalPoints: totalPoints,
      loadPackages: loadPackages,
    ),
  );
}

class PointsDetailsPage extends ConsumerStatefulWidget {
  const PointsDetailsPage({
    this.refreshOnOpen = true,
    this.loadPointsLogOnOpen = true,
    this.pointsLogPageLoader,
    this.pointPackageLoader,
    super.key,
  });

  final bool refreshOnOpen;
  final bool loadPointsLogOnOpen;
  final PointsLogPageLoader? pointsLogPageLoader;
  final PointPackageLoader? pointPackageLoader;

  @override
  ConsumerState<PointsDetailsPage> createState() => _PointsDetailsPageState();
}

class _PointsDetailsPageState extends ConsumerState<PointsDetailsPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<UserPointsLogEntry> _entries = [];
  late final UserPointsLogRepository? _pointsLogRepository;
  late final PointPackageRepository? _pointPackageRepository;
  bool _sheetOpen = false;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _loadError;
  int _nextPage = 1;

  @override
  void initState() {
    super.initState();
    final networkApi = NetworkApi(ref.read(dioProvider));
    _pointsLogRepository = widget.pointsLogPageLoader == null
        ? UserPointsLogRepository(networkApi)
        : null;
    _pointPackageRepository = widget.pointPackageLoader == null
        ? PointPackageRepository(networkApi)
        : null;
    _scrollController.addListener(_handleScroll);
    if (widget.refreshOnOpen) unawaited(_refreshUser());
    if (widget.loadPointsLogOnOpen) {
      unawaited(_loadPointsLog(firstPage: true));
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _refreshUser() async {
    try {
      await ref.read(userProvider.notifier).refreshUser();
    } catch (_) {
      // Keep the last globally cached user visible when refresh fails.
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 240) {
      unawaited(_loadPointsLog());
    }
  }

  Future<UserPointsLogPage> _fetchPointsLogPage(int page) {
    final loader = widget.pointsLogPageLoader;
    if (loader != null) return loader(page, _pageSize);
    return _pointsLogRepository!.fetchPage(page: page, pageSize: _pageSize);
  }

  Future<List<PointPackage>> _fetchPointPackages() {
    final loader = widget.pointPackageLoader;
    if (loader != null) return loader();
    return _pointPackageRepository!.fetchAll();
  }

  Future<void> _loadPointsLog({bool firstPage = false}) async {
    if (_isInitialLoading || _isLoadingMore) return;
    if (!firstPage && !_hasMore) return;

    final requestedPage = firstPage ? 1 : _nextPage;
    setState(() {
      _loadError = null;
      if (firstPage) {
        _isInitialLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final result = await _fetchPointsLogPage(requestedPage);
      if (!mounted) return;
      final knownIds =
          firstPage ? <int>{} : _entries.map((entry) => entry.id).toSet();
      final newEntries = result.items
          .where((entry) => knownIds.add(entry.id))
          .toList(growable: false);
      setState(() {
        if (firstPage) _entries.clear();
        _entries.addAll(newEntries);
        _nextPage = result.page + 1;
        _hasMore = result.hasMore && result.items.isNotEmpty;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load points log page $requestedPage: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final memberCoins = user?.memberCoins ?? 1100;
    final otherCoins = user?.otherCoins ?? 100;
    final pointPackageCoins = user?.pointPackageCoins ?? 88;
    final totalPoints = user?.allCoins ?? 1750;
    final topPadding =
        math.max(MediaQuery.paddingOf(context).top, 52).toDouble();

    final pageBody = Column(
      children: [
        SizedBox(
          height: topPadding + 56,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: SizedBox.square(
                      dimension: 40,
                      child: IconButton(
                        key: const Key('points-details-back'),
                        tooltip: l10n.back,
                        padding: EdgeInsets.zero,
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.pointsDetailsTitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('points-details-scroll'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              _PointsSummaryCard(
                totalPoints: totalPoints,
                memberCoins: memberCoins,
                otherCoins: otherCoins,
                pointPackageCoins: pointPackageCoins,
                onRecharge: () => _showRechargeSheet(totalPoints),
              ),
              const SizedBox(height: 26),
              Text(
                l10n.pointsDetailsTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.pointsUsageDescription,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _buildPointsLogCard(l10n),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: _sheetOpen
          ? ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
              child: pageBody,
            )
          : pageBody,
    );
  }

  Widget _buildPointsLogCard(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('points-transaction-card'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: _pointsCardDecoration(context),
      child: _isInitialLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                  key: Key('points-log-initial-loading'),
                ),
              ),
            )
          : _entries.isEmpty
              ? _PointsLogEmptyState(
                  hasError: _loadError != null,
                  onRetry: () => _loadPointsLog(firstPage: true),
                )
              : Column(
                  children: [
                    for (var index = 0; index < _entries.length; index++) ...[
                      _PointsTransactionRow(entry: _entries[index]),
                      if (index != _entries.length - 1)
                        const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 24),
                    if (_isLoadingMore)
                      const SizedBox.square(
                        key: Key('points-log-loading-more'),
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_loadError != null)
                      TextButton.icon(
                        key: const Key('points-log-retry-more'),
                        onPressed: _loadPointsLog,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.retry),
                      )
                    else
                      Text(
                        l10n.pointsHistoryNotice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
    );
  }

  Future<void> _showRechargeSheet(int totalPoints) async {
    setState(() => _sheetOpen = true);
    await showRechargePointsSheet(
      context: context,
      totalPoints: totalPoints,
      loadPackages: _fetchPointPackages,
    );
    if (mounted) setState(() => _sheetOpen = false);
  }
}

class _PointsSummaryCard extends StatelessWidget {
  const _PointsSummaryCard({
    required this.totalPoints,
    required this.memberCoins,
    required this.otherCoins,
    required this.pointPackageCoins,
    required this.onRecharge,
  });

  final int totalPoints;
  final int memberCoins;
  final int otherCoins;
  final int pointPackageCoins;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('points-summary-card'),
      height: 203,
      padding: const EdgeInsets.all(20),
      decoration: _pointsCardDecoration(context),
      child: Column(
        children: [
          SizedBox(
            height: 31,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: Center(
                    child: Image.asset(
                      'assets/images/assets_points.png',
                      key: const Key('points-details-icon'),
                      width: 20,
                      height: 13.24,
                    ),
                  ),
                ),
                Text(
                  '$totalPoints',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 0.8,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 122,
                  height: 30,
                  child: InkWell(
                    key: const Key('points-recharge-entry'),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onTap: onRecharge,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n.rechargePointsPackage,
                              maxLines: 1,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 30,
                          child: Center(
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: colorScheme.onSurface,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 0, thickness: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 20),
          _PointsBalanceRow(
            label: l10n.rechargedPoints,
            value: '$memberCoins',
          ),
          const SizedBox(height: 10),
          _PointsBalanceRow(label: l10n.giftPoints, value: '$otherCoins'),
          const SizedBox(height: 10),
          _PointsBalanceRow(
            label: l10n.pointsPackage,
            value: '$pointPackageCoins',
          ),
        ],
      ),
    );
  }
}

class _RechargePointsSheet extends StatefulWidget {
  const _RechargePointsSheet({
    required this.totalPoints,
    required this.loadPackages,
  });

  final int totalPoints;
  final PointPackageLoader loadPackages;

  @override
  State<_RechargePointsSheet> createState() => _RechargePointsSheetState();
}

class _RechargePointsSheetState extends State<_RechargePointsSheet> {
  List<PointPackage> _packages = const [];
  PointPackage? _selectedPackage;
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackages(showLoading: false));
  }

  Future<void> _loadPackages({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final packages = await widget.loadPackages();
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _selectedPackage = packages.isEmpty ? null : packages.first;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load point packages: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = math.min(663.0, MediaQuery.sizeOf(context).height);

    return Container(
      key: const Key('points-recharge-sheet'),
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 35,
            child: Center(
              child: Text(
                l10n.rechargePointsPackage,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${widget.totalPoints}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 31 / 30,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    l10n.pointsBalance,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 97,
                  height: 40,
                  child: FilledButton(
                    key: const Key('points-upgrade-membership'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : AppColors.surfaceTintStrong,
                      foregroundColor: isDark
                          ? colorScheme.onSurface
                          : AppColors.textPrimary,
                      side: isDark
                          ? BorderSide(color: colorScheme.outlineVariant)
                          : BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () {},
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.upgradeMembership,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 342,
            child: _buildPackageGrid(l10n),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            width: double.infinity,
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 22 / 14,
                ),
                children: [
                  TextSpan(text: '${l10n.rechargeMembershipNotice}\n'),
                  TextSpan(text: '${l10n.customerServiceContact}\n'),
                  TextSpan(text: l10n.rechargeAgreementPrefix),
                  TextSpan(
                    text: l10n.userAgreement,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: l10n.conjunctionAnd),
                  TextSpan(
                    text: l10n.privacyPolicy,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              key: const Key('points-recharge-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
              ),
              onPressed: _selectedPackage == null
                  ? null
                  : () => Navigator.pop(context, _selectedPackage),
              child: Text(
                l10n.confirm,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageGrid(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('point-packages-loading'),
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.pointPackagesLoadFailed),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('point-packages-retry'),
              onPressed: _loadPackages,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_packages.isEmpty) {
      return Center(child: Text(l10n.pointPackagesEmpty));
    }

    return GridView.builder(
      key: const Key('point-packages-grid'),
      padding: EdgeInsets.zero,
      itemCount: _packages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 104,
      ),
      itemBuilder: (context, index) {
        final package = _packages[index];
        return _PointsPackageCard(
          package: package,
          selected: _selectedPackage?.id == package.id,
          onTap: () => setState(() => _selectedPackage = package),
        );
      },
    );
  }
}

class _PointsPackageCard extends StatelessWidget {
  const _PointsPackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final PointPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: selected
          ? null
          : isDark
              ? colorScheme.surfaceContainerHigh
              : const Color(0xFFFBFAFF),
      gradient: selected
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.primaryContainer,
                    ]
                  : [AppColors.surface, AppColors.surfaceTint],
              stops: const [.33, 1],
            )
          : null,
      borderRadius: BorderRadius.circular(24),
      border: !selected && isDark
          ? Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            )
          : null,
    );

    return Semantics(
      selected: selected,
      button: true,
      label: '${package.totalPoints}',
      child: DecoratedBox(
        key: Key('points-package-${package.totalPoints}'),
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: CustomPaint(
              key: selected ? const Key('points-package-selected') : null,
              foregroundPainter: selected
                  ? const _DashedRoundedBorderPainter(
                      color: AppColors.brand,
                      radius: 24,
                    )
                  : null,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 15,
                          child: Center(
                            child: Image.asset(
                              'assets/images/assets_points.png',
                              width: 15,
                              height: 9.93,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${package.totalPoints}',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            height: 21 / 25,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatPackagePrice(package),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 24 / 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatPackagePrice(PointPackage package) {
  final amount = package.priceAmount == package.priceAmount.truncateToDouble()
      ? package.priceAmount.toInt().toString()
      : package.priceAmount.toStringAsFixed(2);
  return switch (package.currency.toUpperCase()) {
    'CNY' => '¥$amount',
    'USD' => '\$$amount',
    _ => '${package.currency} $amount'.trim(),
  };
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 5, metric.length)),
          paint,
        );
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _PointsBalanceRow extends StatelessWidget {
  const _PointsBalanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 18,
              height: 24 / 18,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 72,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                height: 24 / 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsTransactionRow extends StatelessWidget {
  const _PointsTransactionRow({required this.entry});

  final UserPointsLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final title = entry.content.isNotEmpty
        ? entry.content
        : entry.sourceType.isNotEmpty
            ? entry.sourceType
            : l10n.pointsLogUnknownSource;
    final pointsText =
        entry.points > 0 ? '+${entry.points}' : '${entry.points}';

    return SizedBox(
      key: Key('points-log-${entry.id}'),
      height: 43,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatPointsLogTime(entry.createTime),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              pointsText,
              style: TextStyle(
                color:
                    entry.points > 0 ? AppColors.brand : colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsLogEmptyState extends StatelessWidget {
  const _PointsLogEmptyState({required this.hasError, required this.onRetry});

  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            hasError ? Icons.cloud_off_outlined : Icons.receipt_long_outlined,
            size: 28,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            hasError ? l10n.pointsLogLoadFailed : l10n.pointsLogEmpty,
            key: Key(hasError ? 'points-log-error' : 'points-log-empty'),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('points-log-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatPointsLogTime(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

BoxDecoration _pointsCardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  return BoxDecoration(
    color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
    borderRadius: BorderRadius.circular(AppRadii.card),
    boxShadow: isDark
        ? [
            BoxShadow(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ]
        : null,
  );
}
