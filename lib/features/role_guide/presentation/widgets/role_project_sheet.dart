import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/controllers/paged_list_controller.dart';
import '../../../../shared/widgets/app_paged_scroll.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../projects/domain/project.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

/// Selects an account and opens its unique bound conversation.
class RoleProjectSheet extends ConsumerStatefulWidget {
  const RoleProjectSheet({this.forHomeCreation = false, super.key});
  final bool forHomeCreation;

  @override
  ConsumerState<RoleProjectSheet> createState() => _RoleProjectSheetState();
}

class _RoleProjectSheetState extends ConsumerState<RoleProjectSheet> {
  late final PagedListController<Project> _pages;
  late final String? _ownerId;
  Project? _selected;
  bool _opening = false;
  final _requestToken = CancelToken();

  @override
  void initState() {
    super.initState();
    _ownerId = ref.read(userProvider)?.id;
    _pages = PagedListController(
      itemId: (item) => item.id,
      fetch: (page, token) => ref
          .read(projectRepositoryProvider)
          .listProjects(page: page, cancelToken: token),
    )..addListener(_changed);
    _load(reset: true);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool reset = false}) async {
    try {
      await _pages.load(reset: reset);
    } catch (_) {
      if (!mounted || ref.read(userProvider)?.id != _ownerId) return;
      AppToast.error(context, AppLocalizations.of(context)!.projectsLoadFailed);
      if (!reset) rethrow;
    }
  }

  @override
  void dispose() {
    _requestToken.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final project = _selected;
    if (project == null || _opening) return;
    if (widget.forHomeCreation) {
      Navigator.of(context).pop(project.id);
      return;
    }
    final userId = ref.read(userProvider)?.id;
    setState(() {
      _opening = true;
    });
    try {
      final bound = await ref
          .read(projectRepositoryProvider)
          .boundSession(project.id, cancelToken: _requestToken);
      if (!mounted || ref.read(userProvider)?.id != userId) return;
      final session =
          bound ??
          await ref
              .read(projectActionsProvider.notifier)
              .createSession(project.id, project.title);
      if (!mounted || ref.read(userProvider)?.id != userId) return;
      if (session == null) throw StateError('No session available');
      Navigator.of(
        context,
      ).pop<ProjectSessionSelection>((projectId: project.id, session: session));
    } catch (_) {
      if (mounted && ref.read(userProvider)?.id == userId) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.projectSessionsLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, id) {
      if (id != _ownerId && mounted) {
        _requestToken.cancel();
        Navigator.of(context).pop();
      }
    });
    final l10n = AppLocalizations.of(context)!;
    final actionsBusy = ref.watch(projectActionsProvider);
    return RoleGuideSheet(
      key: const Key('role-guide-project-sheet'),
      title: l10n.roleMyProjects,
      initialSize: .68,
      builder: (context, controller) => AppPagedScroll(
        onLoad: _load,
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView.builder(
            key: const Key('role-project-list'),
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _pages.items.length + 1,
            itemBuilder: (context, index) {
              if (index == _pages.items.length) {
                if (_pages.loading) {
                  return AppSkeleton(
                    label: l10n.loadingProjects,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: AppSkeletonBox(height: 32),
                    ),
                  );
                }
                if (_pages.items.isEmpty) {
                  return Text(l10n.noProjects, textAlign: TextAlign.center);
                }
                return SizedBox(height: _pages.hasMore ? 48 : 0);
              }
              final project = _pages.items[index];
              return Padding(
                key: ValueKey(project.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  key: Key('role-project-select-${project.id}'),
                  enabled: !_opening,
                  selected: _selected?.id == project.id,
                  selectedTileColor: roleGuideTint(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.all(15),
                  leading: const AppSvgIcon.asset(
                    'project_default_avatar',
                    size: 50,
                  ),
                  title: Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: _selected?.id == project.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => setState(() => _selected = project),
                ),
              );
            },
          ),
        ),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoleGuideAction(
            key: const Key('role-project-confirm'),
            label: _opening ? l10n.loadingProjects : l10n.roleSwitchProject,
            onPressed: _selected == null || _opening || actionsBusy
                ? null
                : _open,
          ),
        ],
      ),
    );
  }
}
