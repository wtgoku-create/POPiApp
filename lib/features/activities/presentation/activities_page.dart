import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../data/activity_repository.dart';
import '../domain/activity.dart';
import 'widgets/activity_widgets.dart';

/// Lists campaigns using the same visibility rules as the web exchange dialog.
class ActivitiesPage extends ConsumerStatefulWidget {
  const ActivitiesPage({this.repository, super.key});

  final ActivityRepository? repository;

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  late final ActivityRepository _repository;
  ActivityCatalog? _catalog;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ActivityRepository(NetworkApi(ref.read(dioProvider)));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final catalog = await _repository.fetchCatalog();
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ActivityScaffold(
      title: l10n.activityCenter,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ActivityLoadError(onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _catalog!.activities.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(40),
                      children: [
                        Text(l10n.activityEmpty, textAlign: TextAlign.center),
                      ],
                    )
                  : ListView.separated(
                      key: const Key('activity-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      itemCount: _catalog!.activities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final activity = _catalog!.activities[index];
                        return Material(
                          color: dark
                              ? colors.surfaceContainer
                              : Colors.white.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('activity-${activity.id}'),
                            onTap: () => context.push(
                              '/activities/${activity.id}',
                              extra: _catalog,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 90),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  activity.name.isEmpty
                                                      ? l10n.activityUntitled
                                                      : activity.name,
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (activity.tags.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                ActivityBadge(
                                                  tag: activity.tags.first,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            activity.description.isEmpty
                                                ? l10n.activityNoDescription
                                                : activity.description
                                                      .split('\n')
                                                      .first,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const AppSvgIcon.asset(
                                      'activity_chevron',
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
