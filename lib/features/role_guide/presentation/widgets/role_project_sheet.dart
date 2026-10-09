import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../projects/domain/project.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

/// Selects an existing project and opens its most recently updated conversation.
class RoleProjectSheet extends ConsumerStatefulWidget {
  const RoleProjectSheet({super.key});

  @override
  ConsumerState<RoleProjectSheet> createState() => _RoleProjectSheetState();
}

class _RoleProjectSheetState extends ConsumerState<RoleProjectSheet> {
  late Future<List<Project>> _projects;
  Project? _selected;
  bool _opening = false;
  bool _failed = false;
  final _requestToken = CancelToken();

  @override
  void initState() {
    super.initState();
    _projects = ref
        .read(projectRepositoryProvider)
        .listProjects(cancelToken: _requestToken);
  }

  @override
  void dispose() {
    _requestToken.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    final project = _selected;
    if (project == null || _opening) return;
    final userId = ref.read(userProvider)?.id;
    setState(() {
      _opening = true;
      _failed = false;
    });
    try {
      final sessions = await ref
          .read(projectRepositoryProvider)
          .listSessions(project.id, cancelToken: _requestToken);
      if (!mounted || ref.read(userProvider)?.id != userId) return;
      final sorted = [...sessions]
        ..sort(
          (a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
            a.updatedAt?.millisecondsSinceEpoch ?? 0,
          ),
        );
      final session = sorted.isEmpty
          ? await ref
                .read(projectActionsProvider.notifier)
                .createSession(project.id, project.title)
          : sorted.first;
      if (!mounted || ref.read(userProvider)?.id != userId) return;
      if (session == null) throw StateError('No session available');
      Navigator.of(
        context,
      ).pop<ProjectSessionSelection>((projectId: project.id, session: session));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actionsBusy = ref.watch(projectActionsProvider);
    return RoleGuideSheet(
      key: const Key('role-guide-project-sheet'),
      title: l10n.roleMyProjects,
      initialSize: .68,
      builder: (context, controller) => FutureBuilder<List<Project>>(
        future: _projects,
        builder: (context, snapshot) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (snapshot.hasError)
                TextButton(
                  key: const Key('role-project-retry'),
                  onPressed: () => setState(
                    () => _projects = ref
                        .read(projectRepositoryProvider)
                        .listProjects(cancelToken: _requestToken),
                  ),
                  child: Text('${l10n.projectsLoadFailed} · ${l10n.retry}'),
                )
              else if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.data!.isEmpty)
                Text(l10n.noProjects, textAlign: TextAlign.center)
              else
                for (final project in snapshot.data!)
                  Padding(
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
                      leading: Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: roleGuideTint(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const AppSvgIcon.asset('home_drawer_project'),
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
                  ),
            ],
          );
        },
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.projectSessionsLoadFailed),
            ),
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
