import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/popi_membership_entry.dart';
import '../../../shared/widgets/popi_app_bar_actions.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../../assets/domain/library_role.dart';
import '../../projects/domain/project.dart';
import '../data/role_guide_examples.dart';
import '../data/role_generation_repository.dart';
import '../data/home_creation_repository.dart';
import '../domain/home_creation.dart';
import '../domain/home_storyboard.dart';
import '../domain/role_generation.dart';
import '../domain/role_guide_draft.dart';
import 'widgets/role_generation_sheet.dart';
import 'widgets/role_guide_controls.dart';
import 'widgets/role_guide_picker.dart';
import 'widgets/role_guide_summary.dart';
import 'widgets/role_guide_sheet.dart';
import 'widgets/role_profile_sheet.dart';
import 'widgets/role_project_sheet.dart';
import 'widgets/role_generation_panel.dart';
import 'widgets/home_generation_config_sheet.dart';
import 'widgets/role_guide_markdown.dart';
import 'widgets/role_storyboard_body.dart';
import 'widgets/role_generated_video.dart';

/// Character selection, story planning, and a route-local generation workflow.
class RoleGuidePage extends ConsumerStatefulWidget {
  const RoleGuidePage({
    this.generationRepository,
    this.homeRepository,
    this.accountId,
    this.sessionId,
    super.key,
  });

  final RoleGenerationRepository? generationRepository;
  final HomeCreationRepository? homeRepository;
  final String? accountId;
  final String? sessionId;

  @override
  ConsumerState<RoleGuidePage> createState() => _RoleGuidePageState();
}

class _RoleGuidePageState extends ConsumerState<RoleGuidePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _draft = RoleGuideDraft();
  String _category = 'official';
  bool _drawerOpen = false;
  bool _sheetOpen = false;
  RoleGenerationProgress? _progress;
  StreamSubscription<RoleGenerationProgress>? _generation;
  int _generationId = 0;
  late HomeCreationRepository _repository;
  HomeCreation? _home;
  HomeTask? _task;
  HomeConfig? _config;
  num? _estimate;
  Timer? _poll;
  CancelToken _requestToken = CancelToken();
  bool _busy = false;
  bool _failed = false;
  VoidCallback? _retry;
  bool get _live => widget.generationRepository == null;
  List<RoleGuideStory> _stories(AppLocalizations l10n) => _live
      ? (_home?.topics ?? const [])
            .map(
              (topic) => (
                title: topic.title,
                summary: topic.story,
                development: '',
                content: '',
              ),
            )
            .toList()
      : roleGuideStories(l10n, _draft.storyBatch);

  @override
  void initState() {
    super.initState();
    _repository =
        widget.homeRepository ??
        HomeCreationRepository(
          NetworkApi(ref.read(dioProvider)),
          NetworkAgentApi(ref.read(agentDioProvider)),
        );
    ref.listenManual(userProvider.select((user) => user?.id), (_, __) {
      _requestToken.cancel();
      _requestToken = CancelToken();
      _poll?.cancel();
      if (mounted) {
        setState(() {
          _home = null;
          _task = null;
          _config = null;
          _estimate = null;
          _draft.clear();
          _busy = false;
          _failed = false;
          _retry = null;
        });
      }
    });
    if (_live && widget.accountId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _update(
          () => _repository.open(widget.accountId!, cancelToken: _requestToken),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(RoleGuidePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_live &&
        (oldWidget.accountId != widget.accountId ||
            oldWidget.sessionId != widget.sessionId)) {
      if (_home?.accountId == widget.accountId &&
          _home?.sessionId == widget.sessionId) {
        return;
      }
      _requestToken.cancel();
      _requestToken = CancelToken();
      _poll?.cancel();
      _busy = false;
      _home = null;
      _task = null;
      _config = null;
      _estimate = null;
      _draft.clear();
      if (widget.accountId != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _update(
            () =>
                _repository.open(widget.accountId!, cancelToken: _requestToken),
          ),
        );
      }
    }
  }

  void _apply(HomeCreation home, {RoleGuideStep? step}) {
    if (_home?.accountId != home.accountId || _home?.id != home.id) {
      _config = null;
      _estimate = null;
      _draft.clear();
    }
    _home = home;
    _draft.replaceRoles(home.cast, allowEmpty: true);
    _config = home.config ?? _config;
    _task = home.task;
    _progress = _task?.progress;
    final selected = home.topics.indexWhere(
      (topic) => topic.id == home.selectedTopic?.id,
    );
    _draft.storyIndex = selected < 0 ? 0 : selected;
    _draft.step =
        step ??
        (_task != null
            ? RoleGuideStep.generation
            : home.selectedTopic != null
            ? RoleGuideStep.production
            : home.cast.isNotEmpty
            ? RoleGuideStep.story
            : RoleGuideStep.roles);
    _schedulePoll();
  }

  Future<bool> _update(
    Future<HomeCreation> Function() action, {
    RoleGuideStep? step,
  }) async {
    if (_busy || !mounted) return false;
    if (ref.read(userProvider) == null) {
      context.push('/login');
      return false;
    }
    final token = _requestToken;
    setState(() {
      _busy = true;
      _failed = false;
    });
    _retry = () => _update(action, step: step);
    try {
      final home = await action();
      if (!mounted || token.isCancelled) return false;
      setState(() => _apply(home, step: step));
      if (widget.accountId != home.accountId ||
          widget.sessionId != home.sessionId) {
        context.replace(
          Uri(
            path: '/role-guide',
            queryParameters: {
              'accountId': home.accountId,
              'sessionId': home.sessionId,
            },
          ).toString(),
        );
      }
      return true;
    } catch (error) {
      await _recoverConflict(error, token);
      if (mounted && !token.isCancelled) setState(() => _failed = true);
      return false;
    } finally {
      if (mounted && !token.isCancelled) setState(() => _busy = false);
      if (mounted && !token.isCancelled) _schedulePoll();
    }
  }

  Future<void> _recommend() async {
    final home = _home;
    if (home == null || !home.editable) return;
    await _update(
      () => _repository.recommend(home, cancelToken: _requestToken),
      step: RoleGuideStep.story,
    );
  }

  Future<void> _recoverConflict(Object error, CancelToken token) async {
    final home = _home;
    if (home == null ||
        token.isCancelled ||
        !HomeCreationRepository.isConflict(error)) {
      return;
    }
    try {
      final current = await _repository.refresh(home, cancelToken: token);
      if (mounted && !token.isCancelled) {
        setState(() => _apply(current));
        _retry = () => _update(
          () => _repository.refresh(current, cancelToken: _requestToken),
        );
      }
    } catch (_) {
      // Keep the original command available when recovery itself is offline.
    }
  }

  Future<void> _chooseStory() async {
    if (!_live) {
      _step(RoleGuideStep.production);
      return;
    }
    final home = _home;
    if (home == null || !home.editable || home.topics.isEmpty) return;
    final topic = home.topics[_draft.storyIndex];
    await _update(
      () => _repository.selectTopic(home, topic, cancelToken: _requestToken),
      step: RoleGuideStep.production,
    );
  }

  Future<void> _taskCommand(Future<HomeTask> Function() action) async {
    if (_busy || !mounted) return;
    final token = _requestToken;
    _poll?.cancel();
    setState(() {
      _busy = true;
      _failed = false;
    });
    _retry = () => _taskCommand(action);
    try {
      final task = await action();
      if (!mounted || token.isCancelled) return;
      setState(() {
        _task = task;
        _progress = task.progress;
        _draft.step = RoleGuideStep.generation;
      });
      if (!task.needsPolling && task.state != 'paused' && _home != null) {
        final home = _home!;
        _retry = () => _update(
          () => _repository.refresh(home, cancelToken: _requestToken),
        );
        final current = await _repository.refresh(home, cancelToken: token);
        if (!mounted || token.isCancelled) return;
        setState(() => _apply(current));
      }
    } catch (error) {
      await _recoverConflict(error, token);
      if (mounted && !token.isCancelled) setState(() => _failed = true);
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    final task = _task;
    if (task == null || !task.needsPolling || _busy || !_live) return;
    final token = _requestToken;
    _poll = Timer(const Duration(seconds: 2), () async {
      try {
        final next = await _repository.task(task.id, cancelToken: token);
        if (!mounted || token.isCancelled || _busy || _task?.id != task.id) {
          return;
        }
        if (next.revision >= _task!.revision) {
          setState(() {
            _task = next;
            _progress = next.progress;
          });
        }
        if (!next.needsPolling && next.state != 'paused' && _home != null) {
          await _update(() => _repository.refresh(_home!, cancelToken: token));
        }
      } catch (_) {
        if (mounted && !token.isCancelled) setState(() => _failed = true);
      } finally {
        if (mounted && !token.isCancelled) _schedulePoll();
      }
    });
  }

  @override
  void dispose() {
    _generationId++;
    _generation?.cancel();
    _poll?.cancel();
    _requestToken.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _step(RoleGuideStep step) {
    if (_busy) return;
    setState(() => _draft.step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (_busy) return;
    if (_draft.step == RoleGuideStep.generation && _progress?.running == true) {
      return;
    }
    if (_draft.step != RoleGuideStep.roles) {
      _step(RoleGuideStep.values[_draft.step.index - 1]);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _toggleRole(LibraryRole role) {
    if (_busy) return;
    if (_live && !role.readyForHomeCreation) {
      AppToast.info(
        context,
        AppLocalizations.of(context)!.roleNotReadyForVideo,
      );
      return;
    }
    final changed = _draft.toggleRole(role);
    if (changed) {
      setState(() {});
    } else {
      AppToast.info(context, AppLocalizations.of(context)!.roleProjectLimit);
    }
  }

  Future<bool> _startProject() async {
    if (_busy) return false;
    if (_live) {
      final roles = _draft.roles;
      final ok = await _update(
        () => _home == null
            ? _repository.create(roles, cancelToken: _requestToken)
            : _repository.replaceCast(
                _home!,
                roles,
                cancelToken: _requestToken,
              ),
      );
      if (ok &&
          _home!.topics.isEmpty &&
          _home!.selectedTopic == null &&
          _home!.task == null) {
        await _recommend();
      }
      return ok;
    }
    if (!_draft.startProject()) {
      AppToast.info(
        context,
        AppLocalizations.of(context)!.roleSelectProjectFirst,
      );
      return false;
    }
    _step(RoleGuideStep.story);
    return true;
  }

  Future<void> _details(LibraryRole role) =>
      _showSheet<void>((_) => RoleProfileSheet(roles: [role]));

  void _createRole() => context.push(
    Uri(
      path: '/session',
      queryParameters: {
        'prompt': AppLocalizations.of(context)!.createNewRolePrompt,
      },
    ).toString(),
  );

  Future<void> _library({bool editing = false}) async {
    if (_sheetOpen) return;
    final selection = [..._draft.roles];
    setState(() => _sheetOpen = true);
    try {
      await AppSheet.show<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, updateSheet) {
            final l10n = AppLocalizations.of(context)!;
            return RoleGuideSheet(
              key: const Key('role-guide-library-sheet'),
              title: l10n.roleLibrary,
              builder: (context, controller) => RoleGuidePicker(
                fullLibrary: true,
                scrollController: controller,
                initialCategory: _category,
                selected: () => editing ? selection : _draft.roles,
                onToggle: (role) {
                  if (_busy) return;
                  if (_live && !role.readyForHomeCreation) {
                    AppToast.info(context, l10n.roleNotReadyForVideo);
                    return;
                  }
                  if (editing) {
                    final index = selection.indexWhere(
                      (item) => item.id == role.id,
                    );
                    if (index >= 0) {
                      selection.removeAt(index);
                    } else if (selection.length < RoleGuideDraft.maxRoles) {
                      selection.add(role);
                    } else {
                      AppToast.info(context, l10n.roleProjectLimit);
                    }
                  } else {
                    _toggleRole(role);
                  }
                  updateSheet(() {});
                },
                onDetails: _details,
                onCategoryChanged: (category) =>
                    setState(() => _category = category),
                onCreate: () {
                  Navigator.of(sheetContext).pop();
                  _createRole();
                },
              ),
              footer: RoleGuideAction(
                key: const Key('role-library-create-project'),
                label: editing
                    ? l10n.roleEditProjectRoles
                    : l10n.roleCreateProject,
                count: editing ? selection.length : _draft.roles.length,
                onPressed:
                    (!editing || !_live) &&
                        (editing ? selection : _draft.roles).isEmpty
                    ? null
                    : () async {
                        if (editing) {
                          if (_live) {
                            final home = _home!;
                            final ok = await _update(
                              () => _repository.replaceCast(
                                home,
                                selection,
                                cancelToken: _requestToken,
                              ),
                              step: selection.isEmpty
                                  ? RoleGuideStep.roles
                                  : RoleGuideStep.story,
                            );
                            if (ok && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            if (ok && selection.isNotEmpty) await _recommend();
                          } else if (_draft.replaceRoles(selection)) {
                            _step(RoleGuideStep.story);
                            Navigator.of(sheetContext).pop();
                          }
                        } else if (await _startProject()) {
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }
                      },
              ),
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  Future<void> _configure() async {
    if (_sheetOpen) return;
    if (_live) {
      final result = await _showSheet<HomeGenerationConfiguration>(
        (_) => HomeGenerationConfigSheet(
          repository: _repository,
          sessionId: _home!.sessionId,
          saved: _config,
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _config = result.config;
          _estimate = result.points;
        });
      }
      return;
    }
    setState(() => _sheetOpen = true);
    try {
      final settings = await AppSheet.show<RoleGenerationSettings>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (_) => RoleGenerationSheet(
          initialSettings: _draft.settings,
          videoOnly: true,
        ),
      );
      if (settings != null && mounted) {
        setState(() => _draft.settings = settings);
      }
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  String _plan() {
    final l10n = AppLocalizations.of(context)!;
    final settings = _draft.settings ?? const RoleGenerationSettings();
    final story = roleGuideStories(l10n, _draft.storyBatch)[_draft.storyIndex];
    String roles(List<LibraryRole> items) =>
        items.map((role) => '${role.title} [${role.id}]').join(', ');
    return '${l10n.roleVideoPlanPrompt(l10n.roleProjectName(_draft.roles.first.title), roles(_draft.roles), roles(_draft.cast), story.title, story.summary, settings.model.label, '${settings.videoResolution}P / ${settings.videoRatio.label}', '${settings.imageResolution}P / ${settings.imageRatio.label}', settings.quantity)}\n${l10n.roleDuration}: ${settings.duration == null ? l10n.roleDurationAutomatic : l10n.roleDurationSeconds(settings.duration.toString())}\n${l10n.roleStoryDevelopment}: ${story.development}\n${l10n.roleStoryboardContent}:\n${story.content}';
  }

  void _viewPlan() => context.push(
    Uri(
      path: '/session',
      queryParameters: _live
          ? {'sessionId': _home!.sessionId}
          : {'prompt': _plan()},
    ).toString(),
  );

  void _produce() {
    if (_live) {
      if (_busy || _home == null || !_home!.editable) return;
      if (_config == null || _estimate == null) {
        _configure();
        return;
      }
      final home = _home!;
      final config = _config!;
      _update(
        () => _repository.generate(home, config, cancelToken: _requestToken),
      );
      return;
    }
    if (_progress?.running == true) return;
    final settings = _draft.settings;
    if (settings == null) {
      _configure();
      return;
    }
    final generationId = ++_generationId;
    _generation?.cancel();
    setState(() => _progress = const RoleGenerationProgress());
    _step(RoleGuideStep.generation);
    _generation = widget.generationRepository!
        .generate(_plan())
        .listen(
          (progress) {
            if (mounted && generationId == _generationId) {
              setState(() => _progress = progress);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (mounted && generationId == _generationId) {
              setState(
                () => _progress = RoleGenerationProgress(
                  status: RoleGenerationStatus.failed,
                  stage: _progress?.stage ?? 0,
                ),
              );
            }
          },
          onDone: () {
            if (mounted &&
                generationId == _generationId &&
                _progress?.running == true) {
              setState(
                () => _progress = RoleGenerationProgress(
                  status: RoleGenerationStatus.failed,
                  stage: _progress!.stage,
                ),
              );
            }
          },
        );
  }

  Future<void> _stopProduction() async {
    final l10n = AppLocalizations.of(context)!;
    final generationId = _generationId;
    final stop = await AppDialog.confirm(
      context: context,
      title: l10n.roleStopProductionTitle,
      description: l10n.roleStopProductionDescription,
      cancelLabel: l10n.roleKeepGenerating,
      confirmLabel: l10n.roleStopProduction,
      confirmKey: const Key('role-guide-confirm-stop'),
      destructive: true,
    );
    if (!mounted ||
        stop != true ||
        _progress?.running != true ||
        generationId != _generationId) {
      return;
    }
    if (_live) {
      final task = _task!;
      await _taskCommand(
        () => _repository.control(task, 'cancel', cancelToken: _requestToken),
      );
      return;
    }
    _generationId++;
    _generation?.cancel();
    setState(
      () => _progress = RoleGenerationProgress(
        status: RoleGenerationStatus.canceled,
        stage: _progress!.stage,
      ),
    );
  }

  Future<T?> _showSheet<T>(WidgetBuilder builder) async {
    if (_sheetOpen) return null;
    setState(() => _sheetOpen = true);
    try {
      return await AppSheet.show<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: builder,
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  Future<void> _profiles({String? initialRoleId}) async {
    if (_busy) return;
    final home = _home;
    await _showSheet<void>(
      (_) => RoleProfileSheet(
        roles: home?.castForEditing ?? _draft.roles,
        initialRoleId: initialRoleId,
        useSnapshot: home != null,
        onSaveCreationProfile: _live && home?.editable == true
            ? _saveCreationProfile
            : null,
      ),
    );
  }

  Future<List<LibraryRole>> _saveCreationProfile(
    String roleId,
    Map<String, Object?> profile,
  ) async {
    final home = _home;
    if (_busy || home?.editable != true) {
      throw StateError('Creation is not editable');
    }
    final token = _requestToken;
    late HomeCreation updated;
    setState(() => _busy = true);
    try {
      updated = await _repository.saveRoleProfile(
        home!,
        roleId,
        profile,
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) {
        throw StateError('Creation is no longer active');
      }
      setState(() {
        _failed = false;
        _retry = null;
        _apply(updated, step: RoleGuideStep.story);
      });
      AppToast.success(context, AppLocalizations.of(context)!.roleChangesSaved);
    } catch (error) {
      await _recoverConflict(error, token);
      rethrow;
    } finally {
      if (mounted && !token.isCancelled) setState(() => _busy = false);
    }
    if (mounted && !token.isCancelled) await _recommend();
    return updated.castForEditing;
  }

  Widget _projectSummary() => RoleProjectSummary(
    roles: _draft.roles,
    onViewProfile: _busy
        ? null
        : () => _profiles(initialRoleId: _draft.roles.first.id),
  );

  Future<void> _storyDetails(RoleGuideStory story) => _showSheet<void>(
    (_) => RoleGuideSheet(
      key: const Key('role-guide-story-sheet'),
      title: AppLocalizations.of(context)!.roleDetailedStory,
      initialSize: .875,
      builder: (context, controller) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoleGuideTextSection(
                title: l10n.roleStoryOverview,
                text: story.summary,
              ),
              RoleGuideTextSection(
                title: l10n.roleStoryDevelopment,
                text: story.development,
              ),
              RoleGuideTextSection(
                title: l10n.roleStoryContent,
                text: story.content,
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _projects() async {
    if (ref.read(userProvider) == null) {
      context.push('/login');
      return;
    }
    if (_live) {
      final accountId = await _showSheet<String>(
        (_) => const RoleProjectSheet(forHomeCreation: true),
      );
      if (!mounted || accountId == null) return;
      final ok = await _update(
        () => _repository.open(accountId, cancelToken: _requestToken),
      );
      if (ok &&
          _home!.topics.isEmpty &&
          _home!.selectedTopic == null &&
          _home!.task == null) {
        await _recommend();
      }
      return;
    }
    final selection = await _showSheet<ProjectSessionSelection>(
      (_) => const RoleProjectSheet(),
    );
    if (!mounted || selection == null) return;
    context.push(
      Uri(
        path: '/session',
        queryParameters: {'sessionId': selection.session.id},
      ).toString(),
    );
  }

  // Keep the subtree mounted when an overlay toggles the background blur.
  Widget _blur(Widget child) => ImageFiltered(
    enabled: _drawerOpen || _sheetOpen,
    imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final user = ref.watch(userProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasFooter = _draft.step != RoleGuideStep.generation;
    final showBack = _draft.step.index >= RoleGuideStep.production.index;
    final generating =
        _draft.step == RoleGuideStep.generation && _progress?.running == true;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : safeArea.bottom;
    final (title, description) = switch (_draft.step) {
      RoleGuideStep.roles => (l10n.roleGuideTitle, l10n.roleGuideDescription),
      RoleGuideStep.story => (l10n.roleTopicTitle, l10n.roleTopicDescription),
      RoleGuideStep.production => (
        l10n.roleProductionTitle,
        l10n.roleProductionDescription,
      ),
      RoleGuideStep.generation => switch (_progress?.status) {
        RoleGenerationStatus.completed => (
          l10n.roleGeneratedTitle,
          l10n.roleGeneratedDescription,
        ),
        RoleGenerationStatus.canceled => (
          l10n.roleGenerationCanceledTitle,
          l10n.roleGenerationCanceledDescription,
        ),
        RoleGenerationStatus.failed => (
          l10n.roleGenerationFailedTitle,
          l10n.roleGenerationFailedDescription,
        ),
        _ => (l10n.roleGeneratingTitle, l10n.roleGeneratingDescription),
      },
    };

    return PopScope(
      canPop: _draft.step == RoleGuideStep.roles,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? colors.surface : null,
          gradient: dark
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEDE9FD), Colors.white],
                ),
        ),
        child: Scaffold(
          key: _scaffoldKey,
          // Input sheets handle their own inset while the covered page stays stable.
          resizeToAvoidBottomInset: !_sheetOpen,
          // The app bar already includes the stored status-bar inset.
          primary: false,
          backgroundColor: Colors.transparent,
          drawerScrimColor: const Color(0x33333333),
          drawer: const PopiNavigationDrawer(),
          onDrawerChanged: (open) => setState(() => _drawerOpen = open),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(safeArea.top + 56),
            child: Padding(
              padding: EdgeInsets.only(top: safeArea.top),
              child: _blur(
                AppBar(
                  primary: false,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 56,
                  leadingWidth: showBack ? 100 : 60,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 40,
                          child: IconButton(
                            key: const Key('role-guide-menu'),
                            tooltip: l10n.openNavigation,
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            padding: const EdgeInsets.all(5),
                            icon: AppSvgIcon.asset(
                              'common_navigation_menu',
                              size: 30,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (showBack)
                          SizedBox.square(
                            dimension: 40,
                            child: IconButton(
                              key: const Key('role-guide-back'),
                              tooltip: l10n.backToPreviousPage,
                              onPressed: generating ? null : _back,
                              icon: const Icon(Icons.chevron_left),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    PopiAppBarActions(
                      leadingWidth: showBack ? 100 : 60,
                      membershipEntry: PopiMembershipEntry(
                        points: user?.allCoins ?? 0,
                        showPoints: user != null,
                        label: user == null
                            ? l10n.goToLogin
                            : l10n.upgradeMembership,
                        fontSize: MediaQuery.sizeOf(context).width < 380
                            ? 14
                            : 18,
                        height: 40,
                        onTap: () => context.push(
                          user == null ? '/login' : '/profile/membership',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _blur(
            AbsorbPointer(
              absorbing: _busy,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          key: const Key('role-guide-scroll'),
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            10,
                            20,
                            hasFooter ? 20 : safeArea.bottom + 30,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _RoleGuideHeader(
                                    title: title,
                                    description: description,
                                    step: _draft.step,
                                    onSwitchProject:
                                        _draft.step == RoleGuideStep.roles
                                        ? _projects
                                        : null,
                                  ),
                                  Container(
                                    key: const Key('role-guide-panel'),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _content(l10n),
                                        if (_failed) ...[
                                          const SizedBox(height: 20),
                                          Text(
                                            _draft.step == RoleGuideStep.story
                                                ? l10n.roleStoryRequestFailed
                                                : l10n.roleRequestFailed,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                          TextButton(
                                            key: const Key(
                                              'role-guide-request-retry',
                                            ),
                                            onPressed: _retry,
                                            child: Text(l10n.retry),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasFooter)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                40,
                                12,
                                40,
                                math.max(20, bottomInset),
                              ),
                              child: _stepActions(l10n),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_busy && _draft.step != RoleGuideStep.story)
                    Center(child: _loading(l10n)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      key: const Key('role-guide-loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        if (_draft.step == RoleGuideStep.story) ...[
          const SizedBox(height: 16),
          Text(
            l10n.roleLoadingStories,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _castSummary() => RoleCastSummary(
    cast: _draft.cast,
    onViewProfiles: _profiles,
    onEdit: _busy ? null : () => _library(editing: true),
  );

  // Step actions remain visible independently of the scrollable planning content.
  Widget _stepActions(AppLocalizations l10n) {
    if (_draft.step == RoleGuideStep.roles) {
      return RoleGuideAction(
        key: const Key('role-guide-create-project'),
        label: l10n.roleCreateProject,
        count: _draft.roles.length,
        onPressed: _draft.roles.isEmpty || _busy ? null : _startProject,
      );
    }
    final production = _draft.step == RoleGuideStep.production;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RoleGuideAction(
          key: Key(
            production ? 'role-guide-produce' : 'role-guide-choose-story',
          ),
          label: production ? l10n.roleStartCreating : l10n.roleChooseStory,
          onPressed:
              _busy ||
                  (_live && (_home?.editable != true || _home!.topics.isEmpty))
              ? null
              : production
              ? _produce
              : _chooseStory,
        ),
        if (!production) ...[
          const SizedBox(height: 10),
          RoleGuideAction(
            key: const Key('role-guide-refresh-stories'),
            label: l10n.roleRefreshStories,
            secondary: true,
            showArrow: false,
            onPressed: _busy
                ? null
                : () {
                    if (_live) {
                      _recommend();
                      return;
                    }
                    _draft.refreshStories();
                    _step(RoleGuideStep.story);
                  },
          ),
        ],
      ],
    );
  }

  Widget _content(AppLocalizations l10n) {
    if (_draft.step == RoleGuideStep.roles) {
      return RoleGuidePicker(
        initialCategory: _category,
        selected: () => _draft.roles,
        onToggle: _toggleRole,
        onDetails: _details,
        onCreate: _createRole,
        onCategoryChanged: (category) => setState(() => _category = category),
        onMore: _library,
      );
    }
    if (_draft.step == RoleGuideStep.generation) {
      if (_live) return _liveGeneration(l10n);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.generationRepository!.isPreview) ...[
            Text(
              l10n.rolePreviewNotice,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          RoleGenerationPanel(
            progress: _progress!,
            preview: widget.generationRepository!.isPreview,
            onStop: _stopProduction,
            onRetry: _produce,
            onContinue: () {
              _draft.refreshStories();
              _step(RoleGuideStep.story);
            },
            onViewPlan: _viewPlan,
          ),
          const SizedBox(height: 20),
          Text(l10n.roleProjectSession, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          _projectSummary(),
          const SizedBox(height: 20),
          RoleCastSummary(cast: _draft.cast, onViewProfiles: _profiles),
          const SizedBox(height: 12),
          _artifact(
            l10n.roleScriptContent,
            roleGuideStories(
              l10n,
              _draft.storyBatch,
            )[_draft.storyIndex].development,
          ),
          _artifact(
            l10n.roleStoryboardContent,
            roleGuideStories(
              l10n,
              _draft.storyBatch,
            )[_draft.storyIndex].content,
            isStoryboard: true,
          ),
        ],
      );
    }
    final production = _draft.step == RoleGuideStep.production;
    final stories = _stories(l10n);
    if (stories.isEmpty || (_busy && !production)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _projectSummary(),
          const SizedBox(height: 20),
          _castSummary(),
          if (_busy) _loading(l10n),
          if (!_busy && !_failed) ...[
            const SizedBox(height: 20),
            Text(l10n.roleNoStories, textAlign: TextAlign.center),
          ],
        ],
      );
    }
    final story = stories[_draft.storyIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!production) ...[
          _projectSummary(),
          const SizedBox(height: 20),
          _castSummary(),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                story.title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (production)
              Flexible(
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('role-guide-story-details'),
                    onPressed: () => _storyDetails(story),
                    style: TextButton.styleFrom(
                      backgroundColor: roleGuideTint(context),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.roleDetailedStory,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            if (!production) ...[
              Text(
                l10n.roleStoryPosition(_draft.storyIndex + 1, stories.length),
                style: const TextStyle(fontSize: 12),
              ),
              _storyArrow(l10n.rolePreviousStory, -1, stories.length),
              _storyArrow(l10n.roleNextStory, 1, stories.length),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 20),
        if (production)
          Text(
            l10n.roleStoryOverview,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.375,
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: production ? 154 : 176),
          child: RoleGuideMarkdown(text: story.summary),
        ),
        const SizedBox(height: 20),
        if (production) ...[
          const SizedBox(height: 5),
          Text(
            l10n.roleStoryDevelopment,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          RoleGuideMarkdown(text: story.development),
          const SizedBox(height: 20),
        ],
        if (production) ...[
          TextButton(
            key: const Key('role-guide-configure'),
            onPressed: _configure,
            style: TextButton.styleFrom(
              backgroundColor: roleGuideTint(context),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: const StadiumBorder(),
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: SizedBox(
                        width: 19.2,
                        height: 17.4,
                        child: AppSvgIcon.asset('role_guide_model'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _live
                        ? (_config == null
                              ? l10n.roleModelPending
                              : l10n.roleModelConfigured)
                        : _draft.settings == null
                        ? l10n.roleModelPending
                        : '${_draft.settings!.model.label} / ${_draft.settings!.videoResolution}P / ${_draft.settings!.videoRatio.label}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                const RotatedBox(
                  quarterTurns: 1,
                  child: SizedBox(
                    width: 6,
                    height: 12,
                    child: AppSvgIcon.asset(
                      'role_guide_chevron',
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _live
                ? (_estimate == null
                      ? l10n.roleEstimatePending
                      : l10n.chatEstimatedPoints(_estimate.toString()))
                : _draft.settings == null
                ? l10n.roleEstimatePending
                : l10n.roleEstimatePreview,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!_live && widget.generationRepository!.isPreview) ...[
            const SizedBox(height: 8),
            Text(
              l10n.rolePreviewNotice,
              style: const TextStyle(fontSize: 12, color: AppColors.brand),
            ),
          ],
        ],
      ],
    );
  }

  Widget _liveGeneration(AppLocalizations l10n) {
    final task = _task!;
    final action = task.canConfirmVideo
        ? 'confirm-video'
        : task.allowedActions.contains('resume')
        ? 'resume'
        : task.allowedActions.contains('cancel')
        ? 'cancel'
        : task.allowedActions.contains('retry')
        ? 'retry'
        : task.canContinue
        ? 'continue'
        : null;
    Future<void> perform() async {
      if (action == 'cancel') {
        await _stopProduction();
        return;
      }
      if (action == 'continue') {
        final ok = await _update(
          () =>
              _repository.continueCreation(_home!, cancelToken: _requestToken),
        );
        if (ok && _home?.topics.isEmpty == true) await _recommend();
      } else if (action != null) {
        await _taskCommand(
          () => _repository.control(task, action, cancelToken: _requestToken),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleGenerationPanel(
          progress: _progress!,
          preview: false,
          result: task.videoMediaId == null
              ? null
              : RoleGeneratedVideo(
                  key: ValueKey('role-guide-video-${task.videoMediaId}'),
                  mediaId: task.videoMediaId!,
                  repository: _repository,
                ),
          statusLabel: task.state == 'paused'
              ? l10n.roleTaskPaused
              : task.state == 'awaiting_confirmation'
              ? l10n.chatAwaitingConfirmation
              : null,
          actionLabel: switch (action) {
            'confirm-video' =>
              task.confirmationReason == 'generation_reconfirmation'
                  ? l10n.roleReconfirmVideo
                  : l10n.roleConfirmVideo,
            'resume' => l10n.roleResumeProduction,
            'continue' => l10n.roleContinueCreating,
            'cancel' => l10n.roleStopProduction,
            _ => l10n.retry,
          },
          actionEnabled: action != null && !_busy,
          onAction: perform,
          onStop: _stopProduction,
          onRetry: _produce,
          onContinue: perform,
          onViewPlan: _viewPlan,
        ),
        if (task.allowedActions.contains('pause'))
          TextButton(
            key: const Key('role-guide-pause'),
            onPressed: () => _taskCommand(
              () => _repository.control(
                task,
                'pause',
                cancelToken: _requestToken,
              ),
            ),
            child: Text(l10n.rolePauseProduction),
          ),
        if (task.canConfirmVideo && task.allowedActions.contains('cancel'))
          TextButton(
            onPressed: _stopProduction,
            child: Text(l10n.roleStopProduction),
          ),
        const SizedBox(height: 20),
        _projectSummary(),
        for (final artifact in task.artifacts) ...[
          if (artifact.body.isNotEmpty)
            _artifact(
              artifact.title,
              artifact.body,
              isStoryboard: artifact.kind == 'storyboard',
            ),
        ],
      ],
    );
  }

  Widget _artifact(String title, String text, {bool isStoryboard = false}) {
    final showStoryboard =
        isStoryboard || HomeStoryboard.tryParse(text) != null;
    return ListTileTheme.merge(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        key: ValueKey('role-guide-artifact-$title'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: true,
        title: Text(
          showStoryboard
              ? AppLocalizations.of(context)!.roleStoryboardContent
              : title,
          style: const TextStyle(fontSize: 16),
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: showStoryboard
                ? RoleStoryboardBody(body: text)
                : RoleGuideMarkdown(
                    text: text,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _storyArrow(String tooltip, int direction, int count) {
    final target = _draft.storyIndex + direction;
    return SizedBox(
      width: 24,
      height: 32,
      child: IconButton(
        key: Key(
          direction < 0 ? 'role-guide-previous-story' : 'role-guide-next-story',
        ),
        tooltip: tooltip,
        onPressed: target < 0 || target >= count
            ? null
            : () => setState(() => _draft.storyIndex = target),
        padding: EdgeInsets.zero,
        icon: RotatedBox(
          quarterTurns: direction < 0 ? 2 : 0,
          child: SizedBox(
            width: 6,
            height: 12,
            child: AppSvgIcon.asset(
              'role_guide_chevron',
              color: target < 0 || target >= count
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleGuideHeader extends StatelessWidget {
  const _RoleGuideHeader({
    required this.title,
    required this.description,
    required this.step,
    this.onSwitchProject,
  });
  final String title;
  final String description;
  final RoleGuideStep step;
  final VoidCallback? onSwitchProject;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reading = step != RoleGuideStep.roles;
      final scaler = MediaQuery.textScalerOf(context);
      const titleStyle = TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
      const descriptionStyle = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
      double measure(String text, TextStyle style, double width) =>
          (TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: width)).height;
      final titleHeight = measure(title, titleStyle, constraints.maxWidth - 30);
      final artworkWidth = reading
          ? math.min(136.0, constraints.maxWidth * .34)
          : math.min(105.0, constraints.maxWidth * .30);
      final artworkRight = constraints.maxWidth < 360
          ? 12.0
          : reading
          ? 30.0
          : 48.0;
      final descriptionWidth =
          constraints.maxWidth - artworkWidth - artworkRight - 25;
      final descriptionTop = math.max(62.0, titleHeight + 16);
      final height = math.max(
        154.0,
        descriptionTop +
            measure(description, descriptionStyle, descriptionWidth) +
            (onSwitchProject != null ? 40 : 30),
      );
      return SizedBox(
        height: height,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                right: artworkRight,
                top: titleHeight > 60 ? titleHeight + 8 : 29,
                child: Image.asset(
                  switch (step) {
                    RoleGuideStep.roles =>
                      'assets/images/role_guide_select_character.png',
                    RoleGuideStep.story =>
                      'assets/images/role_guide_story_character.png',
                    RoleGuideStep.production =>
                      'assets/images/role_guide_production_character.png',
                    RoleGuideStep.generation =>
                      'assets/images/role_guide_generation_character.png',
                  },
                  width: artworkWidth,
                  height: reading ? 140 : 155,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: 15,
                right: 15,
                top: 0,
                child: Text(title, style: titleStyle),
              ),
              Positioned(
                left: 15,
                top: descriptionTop,
                width: descriptionWidth,
                child: Text(description, style: descriptionStyle),
              ),
              if (onSwitchProject != null)
                Positioned(
                  left: 7,
                  top:
                      descriptionTop +
                      measure(description, descriptionStyle, descriptionWidth),
                  child: TextButton(
                    key: const Key('role-guide-switch-project'),
                    onPressed: onSwitchProject,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.roleSwitchProject,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
