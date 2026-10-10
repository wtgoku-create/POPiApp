import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/type/notification_type.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';
import 'notification_detail_page.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_scaffold.dart';

/// The current user's system announcements and personal notifications.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({this.repository, super.key});

  final NotificationRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(userProvider.select((user) => user?.id));
    return NotificationScaffold(
      title: l10n.notifications,
      child: userId == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.notificationLoginRequired,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    child: Text(l10n.loginOrRegister),
                  ),
                ],
              ),
            )
          : _NotificationInbox(
              key: ValueKey(userId),
              userId: userId,
              repository:
                  repository ??
                  NotificationRepository(NetworkApi(ref.read(dioProvider))),
            ),
    );
  }
}

class _NotificationInbox extends StatefulWidget {
  const _NotificationInbox({
    required this.repository,
    required this.userId,
    super.key,
  });

  final NotificationRepository repository;
  final String userId;

  @override
  State<_NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<_NotificationInbox> {
  NotificationType _type = NotificationType.system;
  final _opened = {NotificationType.system};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 268),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                children: [
                  for (final type in NotificationType.values)
                    Expanded(
                      child: Semantics(
                        selected: _type == type,
                        child: TextButton(
                          key: ValueKey('notification-tab-${type.name}'),
                          onPressed: () => setState(() {
                            _type = type;
                            _opened.add(type);
                          }),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 7,
                            ),
                            backgroundColor: _type == type
                                ? scheme.surface
                                : Colors.transparent,
                            foregroundColor: _type == type
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            type == NotificationType.system
                                ? l10n.notificationSystem
                                : l10n.notificationPersonal,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _type == type
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _type.index,
            children: [
              for (final type in NotificationType.values)
                if (_opened.contains(type))
                  _NotificationList(
                    key: ValueKey(type),
                    type: type,
                    userId: widget.userId,
                    repository: widget.repository,
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationList extends StatefulWidget {
  const _NotificationList({
    required this.repository,
    required this.type,
    required this.userId,
    super.key,
  });

  final NotificationRepository repository;
  final NotificationType type;
  final String userId;

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList> {
  final _scroll = ScrollController();
  final _items = <AppNotification>[];
  final _readIds = <int>{};
  final _readingIds = <int>{};
  int _version = 0;
  int _nextPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _failed = false;
  bool _detailOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 160) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore || _failed)) return;
    final version = reset ? ++_version : _version;
    final page = reset ? 1 : _nextPage;
    setState(() {
      _failed = false;
      if (reset) {
        _loading = true;
        _loadingMore = false;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await widget.repository.fetchNotifications(
        widget.type,
        page: page,
      );
      if (!mounted || version != _version) return;
      setState(() {
        if (reset) _items.clear();
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(
          result.items
              .where((item) => ids.add(item.id))
              .map((item) => _readIds.contains(item.id) ? item.asRead() : item),
        );
        _hasMore = result.hasMore;
        _nextPage = page + 1;
      });
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _retry() {
    setState(() => _failed = false);
    unawaited(_load(reset: _items.isEmpty));
  }

  Future<void> _markRead(AppNotification item) async {
    if (!item.isUnread ||
        _readIds.contains(item.id) ||
        !_readingIds.add(item.id)) {
      return;
    }
    try {
      await widget.repository.markRead(item.id);
      if (!mounted) return;
      setState(() {
        _readIds.add(item.id);
        final index = _items.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) _items[index] = _items[index].asRead();
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.notificationReadFailed,
        );
      }
    } finally {
      _readingIds.remove(item.id);
    }
  }

  Future<void> _open(AppNotification item) async {
    if (_detailOpen) return;
    _detailOpen = true;
    unawaited(_markRead(item));
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            NotificationDetailPage(notification: item, userId: widget.userId),
      ),
    );
    _detailOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        key: ValueKey('notification-list-${widget.type.name}'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _failed
                                ? l10n.notificationLoadFailed
                                : l10n.notificationEmpty,
                            textAlign: TextAlign.center,
                          ),
                          if (_failed)
                            TextButton.icon(
                              key: ValueKey(
                                'notification-retry-${widget.type.name}',
                              ),
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.retry),
                            ),
                        ],
                      ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => NotificationCard(
                  key: ValueKey('notification-card-${_items[index].id}'),
                  notification: _items[index],
                  type: widget.type,
                  onTap: () => _open(_items[index]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _loading || _loadingMore
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _failed
                    ? Center(
                        child: TextButton.icon(
                          key: ValueKey(
                            'notification-retry-${widget.type.name}',
                          ),
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.notificationLoadMoreFailed),
                        ),
                      )
                    : _hasMore
                    ? Center(
                        child: TextButton.icon(
                          key: ValueKey(
                            'notification-more-${widget.type.name}',
                          ),
                          onPressed: () => _load(),
                          icon: const Icon(Icons.expand_more),
                          label: Text(l10n.notificationLoadMore),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
