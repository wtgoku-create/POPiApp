import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../data/product_plan_repository.dart';
import '../domain/product_plan.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({
    this.planLoader,
    this.initialPlans,
    this.loadPlansOnOpen = true,
    super.key,
  });

  final Future<List<ProductPlan>> Function()? planLoader;
  final List<ProductPlan>? initialPlans;
  final bool loadPlansOnOpen;

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  List<ProductPlan>? _productPlans;
  int _selectedPlan = 0;
  int _selectedVariant = 0;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _productPlans =
        widget.initialPlans ?? (widget.loadPlansOnOpen ? null : const []);
    if (widget.loadPlansOnOpen && widget.initialPlans == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topPadding =
        math.max(MediaQuery.paddingOf(context).top, 52).toDouble();
    final plans = _productPlans == null ? null : _groupPlans(_productPlans!);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedLevel =
        plans != null && plans.isNotEmpty ? plans[_selectedPlan].level : 1;
    final bottomPadding = math.max(MediaQuery.paddingOf(context).bottom, 20.0);

    return Scaffold(
      body: DecoratedBox(
        key: const Key('membership-background'),
        decoration: BoxDecoration(
          gradient: _membershipBackgroundGradient(
            level: selectedLevel,
            isDark: isDark,
            surface: colorScheme.surface,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: topPadding),
            const _MembershipTopBar(),
            if (plans == null)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('membership-plans-loading'),
                  ),
                ),
              )
            else if (plans.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _loadFailed
                        ? l10n.membershipPlansLoadFailed
                        : l10n.membershipPlansEmpty,
                    key: const Key('membership-plans-empty'),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 10),
              _PlanTabs(
                plans: plans,
                selected: _selectedPlan,
                onSelected: (index) {
                  setState(() {
                    _selectedPlan = index;
                    _selectedVariant = 0;
                  });
                },
              ),
              const SizedBox(height: 30),
              Expanded(
                child: _MembershipPlanCard(
                  group: plans[_selectedPlan],
                  selectedVariant: _selectedVariant,
                  onVariantSelected: (index) {
                    setState(() => _selectedVariant = index);
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: math.min(MediaQuery.sizeOf(context).width - 40, 400.0),
                height: 50,
                child: FilledButton(
                  key: const Key('membership-open-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.onSurface,
                    foregroundColor: colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.membershipComingSoon)),
                    );
                  },
                  child: Text(
                    plans[_selectedPlan].variants[_selectedVariant].buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomPadding),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadPlans() async {
    try {
      final loader = widget.planLoader ??
          ProductPlanRepository(NetworkApi(ref.read(dioProvider))).fetchAll;
      final plans = await loader();
      if (!mounted) return;
      setState(() {
        _productPlans = plans;
        _selectedPlan = 0;
        _selectedVariant = 0;
        _loadFailed = false;
      });
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _productPlans = const [];
          _loadFailed = true;
        });
      }
      debugPrint('Failed to load membership plans: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _MembershipTopBar extends StatelessWidget {
  const _MembershipTopBar();

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            child: SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: const Key('membership-back'),
                tooltip: AppLocalizations.of(context)!.back,
                padding: EdgeInsets.zero,
                onPressed: () => context.pop(),
                icon: Transform.rotate(
                  angle: math.pi / 2,
                  child: AppSvgIcon.asset(
                    'membership_back',
                    size: 40,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTabs extends StatefulWidget {
  const _PlanTabs({
    required this.plans,
    required this.selected,
    required this.onSelected,
  });

  final List<_MembershipPlanGroup> plans;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_PlanTabs> createState() => _PlanTabsState();
}

class _PlanTabsState extends State<_PlanTabs> {
  static const _tabWidth = 177.0;
  final _controller = ScrollController();
  final _viewportKey = GlobalKey();
  late final List<GlobalKey> _tabKeys;
  double? _viewportWidth;

  @override
  void initState() {
    super.initState();
    _tabKeys = List.generate(widget.plans.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _PlanTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabKeys.length != widget.plans.length) {
      _tabKeys = List.generate(widget.plans.length, (_) => GlobalKey());
    }
    if (oldWidget.selected != widget.selected ||
        oldWidget.plans.length != widget.plans.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _alignSelected(true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_viewportWidth != constraints.maxWidth) {
          _viewportWidth = constraints.maxWidth;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _alignSelected(false));
        }
        final trailingPadding = math.max(
          20.0,
          constraints.maxWidth - _tabWidth - 20,
        );
        return SizedBox(
          key: _viewportKey,
          height: 50,
          child: ListView.separated(
            key: const Key('membership-plan-tabs'),
            controller: _controller,
            padding: EdgeInsets.only(left: 20, right: trailingPadding),
            scrollDirection: Axis.horizontal,
            itemCount: widget.plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final active = index == widget.selected;
              return SizedBox(
                key: _tabKeys[index],
                width: _tabWidth,
                height: 50,
                child: InkWell(
                  key: Key('membership-plan-tab-$index'),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  onTap: () => widget.onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? isDark
                              ? colorScheme.surfaceContainerHighest
                              : Colors.white.withValues(alpha: .5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: active
                          ? Border.all(
                              color: isDark
                                  ? colorScheme.outlineVariant
                                  : Colors.white,
                            )
                          : null,
                    ),
                    child: Text(
                      widget.plans[index].title,
                      maxLines: 1,
                      style: TextStyle(
                        color: active
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _alignSelected(bool animate) {
    if (!mounted || !_controller.hasClients) return;
    final tabBox = _tabKeys[widget.selected].currentContext?.findRenderObject();
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (tabBox is! RenderBox || viewportBox is! RenderBox) return;

    final tabLeft = tabBox.localToGlobal(Offset.zero).dx;
    final viewportLeft = viewportBox.localToGlobal(Offset.zero).dx;
    final target = (_controller.offset + tabLeft - viewportLeft - 20)
        .clamp(0.0, _controller.position.maxScrollExtent);
    if ((target - _controller.offset).abs() < .5) return;
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpTo(target);
    }
  }
}

class _MembershipPlanCard extends StatelessWidget {
  const _MembershipPlanCard({
    required this.group,
    required this.selectedVariant,
    required this.onVariantSelected,
  });

  final _MembershipPlanGroup group;
  final int selectedVariant;
  final ValueChanged<int> onVariantSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = group.variants[selectedVariant];
    return Container(
      key: const Key('membership-plan-card'),
      width: math.min(MediaQuery.sizeOf(context).width - 40, 400.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh
            : Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: isDark ? colorScheme.outlineVariant : Colors.white,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: const Key('membership-discount-badge'),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    plan.discount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '¥',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  plan.price,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 36,
                    height: 44 / 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.perMonth,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '¥${plan.originalPrice}',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: .7),
                      fontSize: 16,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 24,
            child: Text(
              plan.pointAmount,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 24 / 14,
              ),
            ),
          ),
          const SizedBox(height: 9),
          _PlanPointsSelector(
            plans: group.variants,
            selected: selectedVariant,
            onSelected: onVariantSelected,
          ),
          SizedBox(
            height: 24,
            child: Row(
              children: [
                AppSvgIcon.asset(
                  'membership_info',
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    l10n.membershipPointsBreakdown(
                      plan.packagePoints,
                      plan.giftPoints,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 24 / 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _BenefitsPanel(plan: plan)),
        ],
      ),
    );
  }
}

class _PlanPointsSelector extends StatelessWidget {
  const _PlanPointsSelector({
    required this.plans,
    required this.selected,
    required this.onSelected,
  });

  final List<_MembershipPlan> plans;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final multiple = plans.length > 1;
    return SizedBox(
      height: multiple ? 41 : 31,
      child: Row(
        children: [
          for (var index = 0; index < plans.length; index++) ...[
            InkWell(
              key: Key('membership-points-option-$index'),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: multiple ? () => onSelected(index) : null,
              child: Container(
                width: multiple
                    ? plans[index].points.toString().length > 4
                        ? 125
                        : 111
                    : null,
                height: multiple ? 41 : 31,
                padding: EdgeInsets.symmetric(horizontal: multiple ? 10 : 0),
                decoration: BoxDecoration(
                  color: multiple && selected == index
                      ? colorScheme.primary.withValues(alpha: .1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(
                        child: AppSvgIcon.asset(
                          'membership_points',
                          size: 14,
                        ),
                      ),
                    ),
                    if (multiple)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${plans[index].points}',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 25,
                              height: 24 / 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '${plans[index].points}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 30,
                          height: 31 / 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (index != plans.length - 1) const SizedBox(width: 10),
          ],
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context)!.pointsPerMonth,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsPanel extends StatelessWidget {
  const _BenefitsPanel({required this.plan});

  final _MembershipPlan plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: const Key('membership-benefits'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : Colors.white.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (plan.featureTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    key: const Key('membership-feature-title-icon'),
                    size: 19,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      plan.featureTitle,
                      key: const Key('membership-feature-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              plan.featureTitle.isEmpty ? 12 : 6,
              14,
              16,
            ),
            child: MarkdownBody(
              key: const Key('membership-description-markdown'),
              data: _normalizeDescriptionMarkdown(plan.description),
              checkboxBuilder: (_) => Icon(
                Icons.check,
                size: 12,
                color: colorScheme.primary,
              ),
              listItemCrossAxisAlignment:
                  MarkdownListItemCrossAxisAlignment.start,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  height: 22 / 14,
                ),
                h3: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  height: 22 / 14,
                  fontWeight: FontWeight.w700,
                ),
                h3Padding: const EdgeInsets.only(top: 4, bottom: 6),
                strong: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                blockSpacing: 6,
                listIndent: 16,
                listBulletPadding: const EdgeInsets.only(right: 4, top: 5),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipPlan {
  const _MembershipPlan({
    required this.level,
    required this.title,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.points,
    required this.packagePoints,
    required this.giftPoints,
    required this.pointAmount,
    required this.featureTitle,
    required this.description,
    required this.buttonText,
  });

  final int level;
  final String title;
  final String price;
  final int originalPrice;
  final String discount;
  final int points;
  final int packagePoints;
  final int giftPoints;
  final String pointAmount;
  final String featureTitle;
  final String description;
  final String buttonText;
}

class _MembershipPlanGroup {
  _MembershipPlanGroup(this.variants);

  final List<_MembershipPlan> variants;

  String get title => variants.first.title;
  int get level => variants.first.level;
}

List<_MembershipPlanGroup> _groupPlans(List<ProductPlan> products) {
  final groups = <_MembershipPlanGroup>[];
  _MembershipPlanGroup? plusGroup;

  for (final product in products.reversed) {
    final plan = _planFromProduct(product);
    if (_isPlusProduct(product)) {
      if (plusGroup == null) {
        plusGroup = _MembershipPlanGroup([plan]);
        groups.add(plusGroup);
      } else {
        plusGroup.variants.add(plan);
      }
    } else {
      groups.add(_MembershipPlanGroup([plan]));
    }
  }
  return groups;
}

bool _isPlusProduct(ProductPlan product) {
  return product.level == 2 || product.title.toLowerCase().contains('plus');
}

_MembershipPlan _planFromProduct(ProductPlan product) {
  final customInfo = product.customInfo;
  return _MembershipPlan(
    level: product.level,
    title: product.title,
    price: _centsToYuan(product.price),
    originalPrice: product.originalPriceAmount,
    discount: customInfo?.discountInfo ?? '',
    points: product.coins + product.bonusPointsAmount,
    packagePoints: product.coins,
    giftPoints: product.bonusPointsAmount,
    pointAmount: customInfo?.pointAmount ?? '',
    featureTitle: customInfo?.featureTitle ?? '',
    description: product.description,
    buttonText: customInfo?.buttonText ?? '',
  );
}

LinearGradient _membershipBackgroundGradient({
  required int level,
  required bool isDark,
  required Color surface,
}) {
  if (isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF241D38), surface],
    );
  }

  return switch (level) {
    1 => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF1EEFA), Color(0xFFF8F8F8)],
      ),
    2 => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF9E9FF), Color(0xFFF8F8F8)],
      ),
    3 => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD9CDFF), Color(0xFFF8F8F8)],
      ),
    _ => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFD8B2),
          Color(0xFFE2D9FF),
          Color(0xFFF8F8F8),
        ],
        stops: [0, .2073, 1],
      ),
  };
}

String _centsToYuan(int cents) {
  final yuan = cents / 100;
  return yuan == yuan.truncateToDouble()
      ? yuan.toInt().toString()
      : yuan.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String _normalizeDescriptionMarkdown(String source) {
  final blocks = source.trim().split(RegExp(r'\n\s*\n+'));
  final markdown = <String>[];
  final titlePattern = RegExp(
    r'^<title>(.*?)</title>$',
    caseSensitive: false,
    dotAll: true,
  );
  final markPattern = RegExp(
    r'<mark>(.*?)</mark>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final rawBlock in blocks) {
    final block = rawBlock.trim();
    if (block.isEmpty) continue;

    final title = titlePattern.firstMatch(block);
    if (title != null) {
      if (markdown.isNotEmpty) markdown.add('---');
      markdown.add('### ${title.group(1)?.trim() ?? ''}');
      continue;
    }

    final highlighted = block.replaceAllMapped(
      markPattern,
      (match) => '**${match.group(1)?.trim() ?? ''}**',
    );
    if (RegExp(r'^(?:[-*+] |#{1,6} |>|---$)').hasMatch(highlighted)) {
      markdown.add(highlighted);
    } else {
      markdown.add('- [x] ${highlighted.replaceAll('\n', '\n  ')}');
    }
  }

  return markdown.join('\n\n');
}
