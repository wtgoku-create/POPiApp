import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../home/presentation/home_page.dart';
import '../data/role_library_repository.dart';
import '../domain/library_role.dart';
import 'role_detail_page.dart';

class RoleLibraryList extends ConsumerStatefulWidget {
  const RoleLibraryList({super.key, required this.category});
  final String category;

  @override
  ConsumerState<RoleLibraryList> createState() => _RoleLibraryListState();
}

class _RoleLibraryListState extends ConsumerState<RoleLibraryList> {
  final _scroll = ScrollController();
  List<LibraryRole> _roles = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  bool _refreshFailed = false;
  int _page = 0;
  int _generation = 0;
  String? _deletingId;
  bool _deleteInProgress = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_nearBottom);
    _refresh();
  }

  @override
  void didUpdateWidget(RoleLibraryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _roles = [];
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _refresh();
    }
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  void _nearBottom() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 200 &&
        _error == null) {
      _loadMore();
    }
  }

  void _fillViewport() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _nearBottom();
  });

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _refreshFailed = false;
    });
    try {
      final result = await ref.read(rolePageLoaderProvider)(
        category: widget.category,
        page: 1,
        pageSize: 20,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _roles = {
          for (final role in result.items) role.id: role,
        }.values.toList();
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _refreshFailed = true;
      });
      if (_roles.isNotEmpty) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.networkRequestFailed,
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        if (_error == null) _fillViewport();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final result = await ref.read(rolePageLoaderProvider)(
        category: widget.category,
        page: _page + 1,
        pageSize: 20,
      );
      if (!mounted || generation != _generation) return;
      final ids = _roles.map((role) => role.id).toSet();
      setState(() {
        _roles.addAll(result.items.where((role) => ids.add(role.id)));
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
        if (_error == null) _fillViewport();
      }
    }
  }

  Future<void> _showRole(LibraryRole role) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoleDetailPage(role: role, category: widget.category),
      ),
    );
  }

  Future<void> _deleteRole(LibraryRole role) async {
    if (_deleteInProgress || widget.category == 'official' || !role.canEdit) {
      return;
    }
    final generation = _generation;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _deleteInProgress = true);
    try {
      final confirmed = await AppDialog.confirm(
        context: context,
        title: l10n.deleteRoleTitle,
        description: l10n.deleteRoleDescription,
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.delete,
        confirmKey: const Key('confirm-delete-role'),
        destructive: true,
      );
      if (confirmed != true || !mounted || generation != _generation) return;
      setState(() => _deletingId = role.id);
      await ref.read(roleDeleteProvider)(role.id);
      if (!mounted) return;
      setState(() => _roles.removeWhere((item) => item.id == role.id));
      // Restart pagination so deleting a row cannot skip the next page's first item.
      await _refresh();
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.networkRequestFailed);
    } finally {
      if (mounted) {
        setState(() {
          _deletingId = null;
          _deleteInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _refresh,
        child: SlidableAutoCloseBehavior(
          child: ListView.separated(
            key: const Key('assets-roles-grid'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: _roles.isEmpty ? 1 : _roles.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (_roles.isEmpty) {
                return SizedBox(
                  height: math.max(
                    320,
                    constraints.maxHeight -
                        30 -
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : _error != null
                        ? _retry(_refresh)
                        : widget.category == 'personal'
                        ? const _MyRolesEmptyState()
                        : Text(l10n.noOfficialRoles),
                  ),
                );
              }
              if (index == _roles.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : _error != null
                        ? _retry(_refreshFailed ? _refresh : _loadMore)
                        : Text(
                            _hasMore ? '' : l10n.noMoreRoles,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
                );
              }
              final role = _roles[index];
              final colors = Theme.of(context).colorScheme;
              return Slidable(
                key: ValueKey('role-slide-${widget.category}-${role.id}'),
                enabled:
                    widget.category != 'official' &&
                    role.canEdit &&
                    !_deleteInProgress,
                endActionPane: ActionPane(
                  extentRatio: math.min(
                    1,
                    100 / math.max(1, constraints.maxWidth - 40),
                  ),
                  motion: const ScrollMotion(),
                  children: [
                    const SizedBox(width: 10),
                    CustomSlidableAction(
                      key: Key('role-list-delete-${role.id}'),
                      onPressed: (_) => _deleteRole(role),
                      backgroundColor: const Color(0xFFCC4646),
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle: math.pi / 2,
                            child: const AppSvgIcon.asset(
                              'role_swipe_delete',
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            l10n.delete,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: Key('assets-role-${role.id}'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: _deletingId == role.id
                        ? null
                        : () => _showRole(role),
                    child: SizedBox(
                      height: 90,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
                        child: Row(
                          children: [
                            _RoleAvatar(role: role),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          role.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (_deletingId == role.id)
                                        const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: colors.onSurfaceVariant,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    role.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _retry(Future<void> Function() action) => TextButton.icon(
    key: const Key('roles-retry'),
    onPressed: action,
    icon: const Icon(Icons.refresh),
    label: Text(AppLocalizations.of(context)!.retryLoadingRoles),
  );
}

class _MyRolesEmptyState extends StatelessWidget {
  const _MyRolesEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const Key('my-roles-empty-state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 316),
          child: Semantics(
            button: true,
            label: l10n.createNewRole,
            child: InkWell(
              key: const Key('my-roles-create'),
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HomePage(initialPrompt: l10n.createNewRolePrompt),
                ),
              ),
              child: ColoredBox(
                color: Colors.transparent,
                child: AspectRatio(
                  aspectRatio: 316 / 207,
                  child: Image.asset(
                    'assets/images/assets_roles_empty_art.png',
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.noRoles,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          l10n.myRolesEmptyDescription,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 16,
            height: 30 / 16,
          ),
        ),
      ],
    );
  }
}

class _RoleAvatar extends StatelessWidget {
  const _RoleAvatar({required this.role});
  final LibraryRole role;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.person_outline)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 70,
        child: role.avatar.isEmpty
            ? placeholder
            : Image.network(
                role.avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}
