import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/project_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/app_menu.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../projects/domain/project.dart';
import '../../../projects/presentation/project_item_menu.dart';

const _projectTransitionDuration = Duration(milliseconds: 220);
const _projectTransitionCurve = Curves.easeInOutCubic;

/// Displays authenticated Studio projects and lazily loads their sessions.
class PopiDrawerProjects extends ConsumerStatefulWidget {
  const PopiDrawerProjects({required this.onOpenConversation, super.key});

  final ValueChanged<ProjectSessionSelection> onOpenConversation;

  @override
  ConsumerState<PopiDrawerProjects> createState() => _PopiDrawerProjectsState();
}

class _PopiDrawerProjectsState extends ConsumerState<PopiDrawerProjects> {
  final _expandedProjects = <String>{};
  final _loadedProjects = <String>{};
  String? _selectedProject;
  String? _userId;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final mutedColor = colors.brightness == Brightness.dark
        ? colors.onSurfaceVariant
        : AppColors.textTertiary;
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final result = ref.watch(projectsProvider);
    final projects = result.isLoading || result.hasError
        ? const <Project>[]
        : result.valueOrNull ?? const <Project>[];
    if (_userId != userId) {
      _userId = userId;
      _initialized = false;
      _expandedProjects.clear();
      _loadedProjects.clear();
      _selectedProject = null;
    }
    if (!_initialized && projects.isNotEmpty) {
      _initialized = true;
      _expandedProjects.addAll(projects.take(2).map((project) => project.id));
      _loadedProjects.addAll(_expandedProjects);
      _selectedProject = projects.first.id;
    }
    if (!result.isLoading && !result.hasError) {
      final ids = projects.map((project) => project.id).toSet();
      _expandedProjects.removeWhere((id) => !ids.contains(id));
      _loadedProjects.removeWhere((id) => !ids.contains(id));
      if (_selectedProject != null && !ids.contains(_selectedProject)) {
        _selectedProject = projects.firstOrNull?.id;
        if (_selectedProject case final String id) {
          _expandedProjects.add(id);
          _loadedProjects.add(id);
        }
      }
    }

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.projectCount(projects.length),
                    key: const Key('drawer-project-count'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedColor, fontSize: 14),
                  ),
                ),
                AppMenuButton(
                  key: const Key('drawer-projects-menu'),
                  tooltip: l10n.projectOptions,
                  size: 30,
                  icon: AppSvgIcon.asset(
                    'home_drawer_more',
                    size: 30,
                    color: mutedColor,
                  ),
                  entries: [
                    AppMenuItem(
                      label: l10n.expandAllProjects,
                      icon: const Icon(Icons.unfold_more),
                      onSelected: () => setState(() {
                        _expandedProjects.addAll(
                          projects.map((item) => item.id),
                        );
                        _loadedProjects.addAll(_expandedProjects);
                      }),
                    ),
                    AppMenuItem(
                      label: l10n.collapseAllProjects,
                      icon: const Icon(Icons.unfold_less),
                      onSelected: () => setState(_expandedProjects.clear),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              for (final id in _loadedProjects) {
                ref.invalidate(projectSessionsProvider(id));
              }
              await ref
                  .refresh(projectsProvider.future)
                  .then<void>((_) {}, onError: (Object _, StackTrace __) {});
            },
            child: ListView(
              key: const Key('drawer-project-list'),
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (userId == null)
                  _ProjectStatus(label: l10n.loginToViewProjects)
                else if (result.isLoading)
                  const _ProjectLoading()
                else if (result.hasError)
                  _ProjectStatus(
                    label: l10n.projectsLoadFailed,
                    onRetry: () => ref.invalidate(projectsProvider),
                  )
                else if (projects.isEmpty)
                  _ProjectStatus(label: l10n.noProjects),
                for (final project in projects)
                  Column(
                    key: ValueKey(project.id),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProjectItemMenu(
                        projectId: project.id,
                        title: project.title,
                        onSessionCreated: (session) {
                          setState(() {
                            _selectedProject = project.id;
                            _expandedProjects.add(project.id);
                            _loadedProjects.add(project.id);
                          });
                          widget.onOpenConversation((
                            projectId: project.id,
                            session: session,
                          ));
                        },
                        child: _ProjectHeader(
                          key: Key('drawer-project-${project.id}'),
                          label: project.title,
                          expanded: _expandedProjects.contains(project.id),
                          selected: _selectedProject == project.id,
                          onTap: () => setState(() {
                            _selectedProject = project.id;
                            _loadedProjects.add(project.id);
                            if (!_expandedProjects.add(project.id)) {
                              _expandedProjects.remove(project.id);
                            }
                          }),
                        ),
                      ),
                      _ProjectConversations(
                        key: Key('drawer-project-conversations-${project.id}'),
                        expanded: _expandedProjects.contains(project.id),
                        child: _loadedProjects.contains(project.id)
                            ? _ProjectSessions(
                                projectId: project.id,
                                onOpenConversation: widget.onOpenConversation,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectConversations extends StatelessWidget {
  const _ProjectConversations({
    required this.expanded,
    required this.child,
    super.key,
  });

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: expanded ? 1 : 0, end: expanded ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _projectTransitionDuration,
      curve: _projectTransitionCurve,
      child: child,
      builder: (context, value, child) {
        // Keep loaded groups mounted to cache sessions and preserve transitions.
        return Offstage(
          offstage: value == 0,
          child: IgnorePointer(
            ignoring: !expanded,
            child: ExcludeSemantics(
              excluding: !expanded,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: value,
                  child: Opacity(opacity: value, child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectSessions extends ConsumerWidget {
  const _ProjectSessions({
    required this.projectId,
    required this.onOpenConversation,
  });

  final String projectId;
  final ValueChanged<ProjectSessionSelection> onOpenConversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final result = ref.watch(projectSessionsProvider(projectId));
    if (result.isLoading) return const _ProjectLoading();
    if (result.hasError) {
      return _ProjectStatus(
        label: l10n.projectSessionsLoadFailed,
        onRetry: () => ref.invalidate(projectSessionsProvider(projectId)),
      );
    }
    final sessions = result.valueOrNull ?? const <ProjectSession>[];
    if (sessions.isEmpty) return _ProjectStatus(label: l10n.noHistory);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final session in sessions)
          ProjectItemMenu(
            projectId: projectId,
            title: session.title,
            session: session,
            child: _ConversationRow(
              key: Key('drawer-conversation-$projectId-${session.id}'),
              label: session.title,
              pinned: session.pinnedAt != null,
              onTap: () =>
                  onOpenConversation((projectId: projectId, session: session)),
            ),
          ),
      ],
    );
  }
}

class _ProjectLoading extends StatelessWidget {
  const _ProjectLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 42,
    child: Center(
      child: SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _ProjectStatus extends StatelessWidget {
  const _ProjectStatus({required this.label, this.onRetry});

  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 35, right: 10),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: AppLocalizations.of(context)!.retry,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
            ),
        ],
      ),
    ),
  );
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurface;
    return Semantics(
      expanded: expanded,
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .05)
            : colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(alpha: .12),
          ),
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  AppSvgIcon.asset(
                    'home_drawer_project',
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox.square(
                    dimension: 20,
                    child: Center(
                      child: AnimatedRotation(
                        turns: expanded ? .25 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : _projectTransitionDuration,
                        curve: _projectTransitionCurve,
                        child: SizedBox(
                          width: 5.20711,
                          height: 9,
                          child: AppSvgIcon.asset(
                            'home_drawer_project_chevron',
                            color: colors.brightness == Brightness.dark
                                ? colors.onSurfaceVariant
                                : AppColors.textTertiary,
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
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.label,
    required this.onTap,
    required this.pinned,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        overlayColor: WidgetStatePropertyAll(
          colors.primary.withValues(alpha: .12),
        ),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.only(left: 35, right: 35),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (pinned) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
