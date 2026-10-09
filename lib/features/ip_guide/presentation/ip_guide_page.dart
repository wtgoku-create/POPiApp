import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/ip_guide_provider.dart';
import '../../../shared/providers/project_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/popi_membership_entry.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../domain/ip_guide_draft.dart';
import '../data/ip_guide_repository.dart';
import '../../projects/data/project_repository.dart';
import 'ip_guide_copy.dart';
import 'widgets/ip_guide_choices.dart';
import 'widgets/ip_guide_controls.dart';
import 'widgets/ip_guide_review.dart';
import 'widgets/ip_guide_draft_sheet.dart';

/// Five creation steps autosave one resumable account plan.
class IpGuidePage extends ConsumerStatefulWidget {
  const IpGuidePage({super.key});

  @override
  ConsumerState<IpGuidePage> createState() => _IpGuidePageState();
}

class _IpGuidePageState extends ConsumerState<IpGuidePage>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  IpGuideDraft _draft = IpGuideDraft();
  late final IpGuideRepository _repository;
  late final String? _ownerId;
  final _directionInput = TextEditingController();
  final _feelingInput = TextEditingController();
  final _formatInput = TextEditingController();
  final _nicknameInput = TextEditingController();
  final _audienceInput = TextEditingController();
  late TabController _tabs;
  bool? _reducedMotion;
  int _step = 0;
  bool _drawerOpen = false;
  bool _restoring = false;
  bool _busy = false;
  bool _completed = false;
  bool _saveErrorShown = false;
  bool _draftSheetOpen = false;
  String? _projectSessionId;
  String? _sessionRequestId;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(ipGuideRepositoryProvider);
    _ownerId = ref.read(userProvider)?.id;
    _directionInput.addListener(_updateDraft);
    _feelingInput.addListener(_updateDraft);
    _formatInput.addListener(_updateDraft);
    _nicknameInput.addListener(_updateDraft);
    _audienceInput.addListener(_updateDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _repository.load() != null) unawaited(_start());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reducedMotion) return;
    if (_reducedMotion != null) {
      _tabs.removeListener(_onTabChanged);
      _tabs.dispose();
    }
    _tabs = TabController(
      length: 6,
      initialIndex: _step,
      vsync: this,
      animationDuration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
    )..addListener(_onTabChanged);
    _reducedMotion = reducedMotion;
  }

  void _updateDraft() {
    if (_restoring || _completed || _draft.submitted) return;
    setState(() {
      _draft.directions.customText = _directionInput.text;
      _draft.feelings.customText = _feelingInput.text;
      _draft.customFormat = _formatInput.text;
      _draft.nickname = _nicknameInput.text;
      _draft.audience.customText = _audienceInput.text;
    });
    _save();
  }

  void _save() {
    if (_completed || _step == 0 || _draft.submitted) return;
    unawaited(
      _repository.save(_draft).catchError((Object error) {
        if (!mounted || _saveErrorShown) return;
        _saveErrorShown = true;
        AppToast.info(context, AppLocalizations.of(context)!.ipDraftSaveFailed);
      }),
    );
  }

  Future<void> _start() async {
    if (_draftSheetOpen || _busy) return;
    final saved = _repository.load();
    if (saved != null) {
      _draftSheetOpen = true;
      final resume = await IpGuideDraftSheet.show(context);
      _draftSheetOpen = false;
      if (!mounted || resume == null) return;
      if (resume) {
        _restore(saved);
        _goToStep(saved.step);
        return;
      }
    }
    _restore(IpGuideDraft());
    setState(() => _busy = true);
    try {
      await _repository.save(_draft);
      if (mounted) _goToStep(1);
    } catch (_) {
      if (mounted) {
        AppToast.info(context, AppLocalizations.of(context)!.ipDraftSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restore(IpGuideDraft draft) {
    _restoring = true;
    _draft = draft;
    _directionInput.text = draft.directions.customText;
    _feelingInput.text = draft.feelings.customText;
    _formatInput.text = draft.customFormat;
    _nicknameInput.text = draft.nickname;
    _audienceInput.text = draft.audience.customText;
    _restoring = false;
    setState(() {});
  }

  void _onTabChanged() {
    if (_step == _tabs.index) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = _tabs.index);
    if (_step > 0) _draft.step = _step;
    _save();
  }

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _tabs.index = step;
    } else {
      _tabs.animateTo(step);
    }
  }

  void _next() {
    final l10n = AppLocalizations.of(context)!;
    final invalid = switch (_step) {
      1 => _draft.directions.isEmpty,
      2 => _draft.feelings.isEmpty,
      3 => _draft.presentation == null,
      4 => _draft.audience.isEmpty,
      _ => false,
    };
    if (invalid) {
      AppToast.info(context, _validationMessage(_step, l10n));
      return;
    }
    _goToStep(_step + 1);
  }

  String _validationMessage(int step, AppLocalizations l10n) => switch (step) {
    1 => l10n.ipSelectDirection,
    2 => l10n.ipSelectFeeling,
    4 => l10n.ipSelectAudience,
    _ => l10n.ipSelectPresentation,
  };

  void _toggle<T extends Enum>(
    IpGuideSelection<T> selection,
    T value,
    TextEditingController input,
  ) {
    input.clear();
    final changed = selection.toggle(value);
    if (changed) {
      setState(() {});
      _save();
    } else {
      AppToast.info(context, AppLocalizations.of(context)!.ipMaximumSelections);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _completed) return;
    final l10n = AppLocalizations.of(context)!;
    final missing = _draft.firstIncompleteStep;
    if (missing != null) {
      _goToStep(missing);
      AppToast.info(context, _validationMessage(missing, l10n));
      return;
    }
    if (_draft.nickname.trim().isEmpty) {
      AppToast.info(context, l10n.ipSelectNickname);
      return;
    }
    if (ref.read(userProvider) == null) {
      await context.push('/login');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (ref.read(userProvider)?.id != _ownerId) {
        context.go('/');
        return;
      }
      await _repository.create(_draft, guideAccountProfile(_draft, l10n));
      if (!mounted || ref.read(userProvider)?.id != _ownerId) return;
      ref.invalidate(projectsProvider);
      if (mounted) setState(() => _completed = true);
    } catch (_) {
      if (mounted) AppToast.info(context, l10n.ipCreateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_busy) return;
    if (_step > 0 && !_completed && !_draft.submitted) {
      _goToStep(_step - 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _openProject({bool createContent = false}) async {
    if (_busy || _draft.accountId == null) return;
    if (ref.read(userProvider)?.id != _ownerId) {
      context.go('/');
      return;
    }
    if (!createContent) {
      await context.push(
        '/ip-accounts/${Uri.encodeComponent(_draft.accountId!)}',
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      if (_projectSessionId == null) {
        _sessionRequestId ??= ProjectRepository.createClientRequestId();
        final session = await ref
            .read(projectRepositoryProvider)
            .createSession(
              _draft.accountId!,
              _draft.nickname,
              clientRequestId: _sessionRequestId!,
            );
        _projectSessionId = session.id;
      }
      if (mounted && ref.read(userProvider)?.id == _ownerId) {
        unawaited(
          context.push(
            Uri(
              path: '/session',
              queryParameters: {
                'sessionId': _projectSessionId!,
                if (createContent) 'prompt': l10n.ipFirstContentPrompt,
              },
            ).toString(),
          ),
        );
      }
    } catch (_) {
      if (mounted) AppToast.info(context, l10n.chatRequestFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _directionInput.dispose();
    _feelingInput.dispose();
    _formatInput.dispose();
    _nicknameInput.dispose();
    _audienceInput.dispose();
    super.dispose();
  }

  Widget _blurBehindDrawer(Widget child) => _drawerOpen
      ? ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final user = ref.watch(userProvider);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tabLabels = [
      l10n.ipContentDirection,
      l10n.ipAudienceFeeling,
      l10n.ipPresentation,
      l10n.ipTargetAudience,
      l10n.ipReview,
    ];

    final page = DecoratedBox(
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
            child: _blurBehindDrawer(
              AppBar(
                primary: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 56,
                leadingWidth: 100,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 40,
                        child: IconButton(
                          key: const Key('ip-guide-menu'),
                          tooltip: l10n.openNavigation,
                          padding: const EdgeInsets.all(5),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                          icon: AppSvgIcon.asset(
                            'common_navigation_menu',
                            size: 30,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 40,
                        child: IconButton(
                          key: const Key('ip-guide-back'),
                          tooltip: l10n.back,
                          onPressed: _back,
                          padding: EdgeInsets.zero,
                          icon: Transform.rotate(
                            angle: math.pi / 2,
                            child: AppSvgIcon.asset(
                              'ip_guide_back',
                              size: 40,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: PopiMembershipEntry(
                      points: user?.allCoins ?? 0,
                      showPoints: user != null,
                      label: user == null
                          ? l10n.goToLogin
                          : l10n.upgradeMembership,
                      fontSize: 18,
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
        body: _blurBehindDrawer(
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  if (!_completed)
                    SizedBox(
                      key: const Key('ip-guide-progress'),
                      height: 25,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 54),
                        child: Row(
                          children: [
                            for (var i = 0; i < 5; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Semantics(
                                    key: Key('ip-guide-progress-$i'),
                                    label: tabLabels[i],
                                    selected: _step == i + 1,
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withValues(
                                          alpha: _step == i + 1 ? 1 : .2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _stepWithAction(
                          0,
                          _introduction(l10n),
                          label: l10n.ipGuideStart,
                          onPressed: _busy ? null : _start,
                          top: 102,
                        ),
                        _stepWithAction(
                          1,
                          _selectionStep(l10n, feelings: false),
                          label: l10n.ipNextFeelings,
                          onPressed: _next,
                        ),
                        _stepWithAction(
                          2,
                          _selectionStep(l10n, feelings: true),
                          label: l10n.ipNextPresentation,
                          onPressed: _next,
                        ),
                        _stepWithAction(
                          3,
                          _presentationStep(l10n),
                          label: l10n.ipNextAudience,
                          onPressed: _next,
                        ),
                        _stepWithAction(
                          4,
                          _audienceStep(l10n),
                          label: l10n.ipNextReview,
                          onPressed: _next,
                        ),
                        _scroll(
                          5,
                          Column(
                            children: [
                              if (_completed)
                                _successHeading(l10n)
                              else
                                _heading(5, l10n.ipReviewQuestion),
                              const SizedBox(height: 20),
                              IpGuideReview(
                                draft: _draft,
                                nicknameController: _nicknameInput,
                                onConfirm: _confirm,
                                onReselect: () => _goToStep(1),
                                submitted: _draft.submitted,
                                busy: _busy,
                                completed: _completed,
                                onCreateRole: () => context.push('/role-guide'),
                                onCreateContent: () =>
                                    _openProject(createContent: true),
                                onOpenProject: _openProject,
                              ),
                            ],
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
    return PopScope<void>(
      canPop:
          !_busy &&
          (_step == 0 || _completed || _draft.submitted || _drawerOpen),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: page,
    );
  }

  // Keep the action outside scrolling content and above the keyboard or safe area.
  Widget _stepWithAction(
    int step,
    Widget child, {
    required String label,
    required VoidCallback? onPressed,
    double top = 30,
  }) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : ref.watch(safeAreaInsetsProvider).bottom;
    return Column(
      children: [
        Expanded(child: _scroll(step, child, top: top, bottom: 20)),
        Padding(
          padding: EdgeInsets.fromLTRB(40, 12, 40, bottomInset + 20),
          child: IpGuideNextButton(
            key: Key(step == 0 ? 'ip-guide-start' : 'ip-guide-next-$step'),
            label: label,
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }

  Widget _scroll(int step, Widget child, {double top = 30, double? bottom}) =>
      SingleChildScrollView(
        key: Key('ip-guide-scroll-$step'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          top,
          20,
          bottom ?? ref.watch(safeAreaInsetsProvider).bottom + 20,
        ),
        child: child,
      );

  Widget _heading(int step, String question) => Column(
    children: [
      Text(
        AppLocalizations.of(context)!.ipGuideStep(step),
        style: const TextStyle(
          color: AppColors.brand,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      Text(
        question,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    ],
  );

  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          children[i],
        ],
      ],
    ),
  );

  Widget _introduction(AppLocalizations l10n) => Column(
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: l10n.ipGuideIntroBefore),
            TextSpan(
              text: l10n.ipGuideIntroFiveSteps,
              style: const TextStyle(color: AppColors.brand),
            ),
            TextSpan(text: l10n.ipGuideIntroAfter),
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 20),
      AspectRatio(
        aspectRatio: 400 / 310,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: AppSvgIcon.asset('ip_guide_intro_background'),
            ),
            FractionallySizedBox(
              widthFactor: 268 / 400,
              heightFactor: 282 / 310,
              child: Image.asset(
                'assets/images/ip_guide_intro.png',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _selectionStep(AppLocalizations l10n, {required bool feelings}) {
    final labels = feelings
        ? _draft.feelings.values
              .map((value) => feelingLabel(value, l10n))
              .toList()
        : _draft.directions.values
              .map((value) => directionLabel(value, l10n))
              .toList();
    return Column(
      children: [
        _heading(
          feelings ? 2 : 1,
          feelings ? l10n.ipFeelingQuestion : l10n.ipDirectionQuestion,
        ),
        const SizedBox(height: 20),
        _panel([
          if (feelings)
            IpGuideChoiceGrid<IpAudienceFeeling>(
              values: IpAudienceFeeling.values,
              selection: _draft.feelings,
              label: (value) => feelingLabel(value, l10n),
              description: (value) => feelingDescription(value, l10n),
              onSelected: (value) =>
                  _toggle(_draft.feelings, value, _feelingInput),
              keyPrefix: 'ip-feeling',
            )
          else
            IpGuideChoiceGrid<IpContentDirection>(
              values: IpContentDirection.values,
              selection: _draft.directions,
              label: (value) => directionLabel(value, l10n),
              icon: (value) => 'ip_guide_${value.name}',
              onSelected: (value) =>
                  _toggle(_draft.directions, value, _directionInput),
              keyPrefix: 'ip-direction',
            ),
          IpGuideSelectionSummary(labels: labels),
          IpGuideTextField(
            key: Key(feelings ? 'ip-custom-feeling' : 'ip-custom-direction'),
            controller: feelings ? _feelingInput : _directionInput,
            hint: l10n.ipCustomHint,
          ),
        ]),
      ],
    );
  }

  Widget _presentationStep(AppLocalizations l10n) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    return Column(
      children: [
        _heading(3, l10n.ipPresentationQuestion),
        const SizedBox(height: 20),
        _panel([
          Text(l10n.ipVisualStyle, style: style),
          IpGuidePresentationChoices(
            selected: _draft.presentation,
            onSelected: (value) {
              setState(() => _draft.presentation = value);
              _save();
            },
          ),
          Text(l10n.ipContentFormat, style: style),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final format in IpContentFormat.values)
                ChoiceChip(
                  key: Key('ip-format-${format.name}'),
                  label: Text(formatLabel(format, l10n)),
                  selected:
                      _draft.customFormat.trim().isEmpty &&
                      _draft.format == format,
                  showCheckmark: false,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .05),
                  labelStyle: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  shape: const StadiumBorder(),
                  onSelected: (_) {
                    _formatInput.clear();
                    setState(() => _draft.format = format);
                    _save();
                  },
                ),
            ],
          ),
          IpGuideTextField(
            key: const Key('ip-custom-format'),
            controller: _formatInput,
            hint: l10n.ipCustomHint,
          ),
        ]),
      ],
    );
  }

  Widget _audienceStep(AppLocalizations l10n) => Column(
    children: [
      _heading(4, l10n.ipAudienceQuestion),
      const SizedBox(height: 20),
      _panel([
        IpGuideChoiceGrid<IpTargetAudience>(
          values: IpTargetAudience.values,
          selection: _draft.audience,
          label: (value) => audienceLabel(value, l10n),
          description: (value) => audienceDescription(value, l10n),
          showAvatar: false,
          onSelected: (value) =>
              _toggle(_draft.audience, value, _audienceInput),
          keyPrefix: 'ip-audience',
        ),
        IpGuideSelectionSummary(
          labels: _draft.audience.values
              .map((value) => audienceLabel(value, l10n))
              .toList(),
        ),
        IpGuideTextField(
          key: const Key('ip-custom-audience'),
          controller: _audienceInput,
          hint: l10n.ipCustomHint,
        ),
      ]),
    ],
  );

  Widget _successHeading(AppLocalizations l10n) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ipCreateSuccess,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.ipCreateSuccessDescription,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
      Image.asset(
        'assets/images/ip_guide_success.png',
        width: 135,
        height: 135,
        fit: BoxFit.contain,
      ),
    ],
  );
}
