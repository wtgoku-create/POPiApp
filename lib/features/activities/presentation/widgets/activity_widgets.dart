import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/activity.dart';

class ActivityScaffold extends ConsumerWidget {
  const ActivityScaffold({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final background = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF5F4FA)
        : colors.surface;
    final top = math.max(
      ref.watch(safeAreaInsetsProvider).top,
      MediaQuery.paddingOf(context).top,
    );
    return Scaffold(
      primary: false,
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(top + 56),
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: AppBar(
            primary: false,
            toolbarHeight: 56,
            backgroundColor: background,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            leadingWidth: 70,
            leading: Padding(
              padding: const EdgeInsets.only(left: 15, right: 15),
              child: IconButton(
                key: const Key('activity-back'),
                tooltip: AppLocalizations.of(context)!.back,
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: RotatedBox(
                  quarterTurns: 1,
                  child: AppSvgIcon.asset(
                    'activity_back',
                    size: 40,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ActivityBadge extends StatelessWidget {
  const ActivityBadge({required this.tag, super.key});

  final ActivityTag tag;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
    decoration: BoxDecoration(
      color: tag.background == null
          ? AppColors.brand.withValues(alpha: .05)
          : Color(tag.background!),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      tag.label,
      style: TextStyle(
        fontSize: 12,
        color: tag.foreground == null
            ? AppColors.brand
            : Color(tag.foreground!),
      ),
    ),
  );
}

class ActivityBanner extends StatelessWidget {
  const ActivityBanner({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(
      'assets/images/activity_exchange_banner.png',
      fit: BoxFit.cover,
      alignment: Alignment.centerLeft,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 400 / 227,
        child: url.isEmpty
            ? fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

class ActivityLoadError extends StatelessWidget {
  const ActivityLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.activityLoadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
