import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/project_provider.dart';
import '../providers/user_provider.dart';
import 'app_menu.dart';
import 'app_skeleton.dart';
import 'app_svg_icon.dart';
import '../../features/projects/domain/project.dart';
import '../../features/projects/presentation/project_item_menu.dart';

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
    final projects = result.isReloading || result.hasError
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
                    result.isLoading && projects.isEmpty
                        ? l10n.projectsTitle
                        : l10n.projectCount(projects.length),
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
                  enabled: projects.isNotEmpty,
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
                else if (result.isLoading && projects.isEmpty)
                  const _ProjectSkeleton(key: Key('drawer-projects-skeleton'))
                else if (result.hasError && projects.isEmpty)
                  _ProjectStatus(
                    label: l10n.projectsLoadFailed,
                    onRetry: () => ref.invalidate(projectsProvider),
                  )
                else if (projects.isEmpty)
                  const _ProjectEmptyState(),
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
    final sessions = result.isReloading || result.hasError
        ? const <ProjectSession>[]
        : result.valueOrNull ?? const <ProjectSession>[];
    if (result.isLoading && sessions.isEmpty) {
      return _ProjectSkeleton(
        key: Key('drawer-sessions-skeleton-$projectId'),
        sessionsOnly: true,
      );
    }
    if (result.hasError && sessions.isEmpty) {
      return _ProjectStatus(
        label: l10n.projectSessionsLoadFailed,
        onRetry: () => ref.invalidate(projectSessionsProvider(projectId)),
      );
    }
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

class _ProjectEmptyState extends StatelessWidget {
  const _ProjectEmptyState();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('drawer-projects-empty'),
    height: 180,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: AppSvgIcon.asset(
                'home_drawer_project',
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .25),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.noProjects,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProjectSkeleton extends StatelessWidget {
  const _ProjectSkeleton({this.sessionsOnly = false, super.key});

  final bool sessionsOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget bar(double height) => AppSkeletonBox(height: height);
    Widget row({required bool header, required double widthFactor}) => SizedBox(
      height: 42,
      child: Padding(
        padding: EdgeInsets.only(left: header ? 10 : 35, right: 35),
        child: Row(
          children: [
            if (header) ...[
              SizedBox(width: 20, child: bar(20)),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: bar(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AppSkeleton(
      label: sessionsOnly ? l10n.loadingProjectSessions : l10n.loadingProjects,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++) ...[
            row(header: !sessionsOnly, widthFactor: index.isEven ? .65 : .45),
            if (!sessionsOnly && index < 2) ...[
              row(header: false, widthFactor: .85),
              row(header: false, widthFactor: .6),
            ],
          ],
        ],
      ),
    );
  }
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
