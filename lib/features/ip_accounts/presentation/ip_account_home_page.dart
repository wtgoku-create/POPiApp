import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/ip_account_provider.dart';
import '../../../shared/providers/project_provider.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_expanded_text_field.dart';
import '../../../shared/type/account_input_type.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_glass_app_bar.dart';
import '../../../shared/widgets/app_account_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project.dart';
import '../../session/domain/session_artifact.dart';
import '../../session/presentation/widgets/session_artifacts_sheet.dart';
import '../domain/ip_account_home.dart';
import 'widgets/account_preferences_sheet.dart';
import 'widgets/ip_account_history.dart';

/// Account overview with local loading state and account-bound creation entry.
class IpAccountHomePage extends ConsumerStatefulWidget {
  const IpAccountHomePage({required this.accountId, super.key});
  final String accountId;

  @override
  ConsumerState<IpAccountHomePage> createState() => _IpAccountHomePageState();
}

class _IpAccountHomePageState extends ConsumerState<IpAccountHomePage> {
  final _nicknameController = TextEditingController();
  final _nicknameFocus = FocusNode();
  bool _renaming = false;
  bool _confirmingRename = false;
  String? _renameTitle;
  String? _renameRequestId;
  CancelToken? _token;
  IpAccountHome? _account;
  bool _loading = true;
  bool _failed = false;
  bool _creating = false;
  ProjectSession? _boundSession;
  bool _bindingLoading = false;
  bool _bindingFailed = false;
  List<SessionArtifact> _history = const [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(IpAccountHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dismissRenameConfirmation();
      });
      _creating = false;
      _boundSession = null;
      _bindingLoading = false;
      _bindingFailed = false;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _token?.cancel();
    _nicknameController.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _token?.cancel();
    _nicknameFocus.unfocus();
    _nicknameController.clear();
    _renameTitle = null;
    _renameRequestId = null;
    final token = _token = CancelToken();
    setState(() {
      _loading = true;
      _failed = false;
      _account = null;
      _creating = false;
      _boundSession = null;
      _bindingLoading = false;
      _bindingFailed = false;
      _renaming = false;
      _history = const [];
      _historyLoading = false;
    });
    if (ref.read(userProvider) == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final account = await ref
          .read(ipAccountRepositoryProvider)
          .detail(widget.accountId, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      _nicknameController.text = account.title;
      setState(() {
        _account = account;
        _loading = false;
      });
      unawaited(_loadHistory(account, token));
      if (account.editable) unawaited(_loadBinding(account, token));
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadBinding(IpAccountHome account, CancelToken token) async {
    setState(() {
      _bindingLoading = true;
      _bindingFailed = false;
    });
    try {
      final bound = await ref
          .read(projectRepositoryProvider)
          .boundSession(account.id, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() => _boundSession = bound);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() => _bindingFailed = true);
        AppToast.error(
          context,
          AppLocalizations.of(context)!.networkRequestFailed,
        );
      }
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _bindingLoading = false);
      }
    }
  }

  Future<void> _loadHistory(IpAccountHome account, CancelToken token) async {
    setState(() {
      _historyLoading = true;
    });
    try {
      final page = await ref
          .read(ipAccountRepositoryProvider)
          .creationHistory(account.id, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() => _history = page.items);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.creationHistoryLoadFailed,
        );
      }
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _historyLoading = false);
      }
    }
  }

  Future<void> _openHistory(SessionArtifact creation) async {
    final token = _token;
    final account = _account;
    if (account == null || token == null || token.isCancelled) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SessionArtifactDetailPage(item: creation),
      ),
    );
    if (mounted && !token.isCancelled) {
      await _loadHistory(account, token);
    }
  }

  Future<void> _showHistory() async {
    final token = _token;
    final account = _account;
    if (account == null || token == null || token.isCancelled) return;
    await context.push(
      Uri(
        pathSegments: ['', 'ip-accounts', widget.accountId, 'history'],
      ).toString(),
    );
    if (mounted && !token.isCancelled) {
      await _loadHistory(account, token);
    }
  }

  Future<void> _saveNickname() async {
    final account = _account;
    final title = _nicknameController.text.trim();
    if (account == null ||
        !account.editable ||
        _renaming ||
        _confirmingRename ||
        title.isEmpty) {
      return;
    }
    if (title.characters.length > AccountInputLimits.nicknameCharacters ||
        utf8.encode(title).length > AccountInputLimits.nicknameBytes) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.accountTitleInvalid,
      );
      return;
    }
    if (title == account.title) {
      _nicknameFocus.unfocus();
      return;
    }
    final token = _token!;
    final owner = ref.read(userProvider)?.id;
    final l10n = AppLocalizations.of(context)!;
    _nicknameFocus.unfocus();
    setState(() => _confirmingRename = true);
    bool? confirmed;
    try {
      confirmed = await AppDialog.confirm(
        context: context,
        title: l10n.accountRenameTitle,
        description: l10n.accountRenameConfirm(title),
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
        confirmKey: const Key('ip-account-confirm-nickname'),
      );
    } finally {
      if (mounted) setState(() => _confirmingRename = false);
    }
    if (!mounted ||
        confirmed != true ||
        token.isCancelled ||
        ref.read(userProvider)?.id != owner) {
      return;
    }
    if (title != _renameTitle) {
      _renameTitle = title;
      _renameRequestId = ProjectRepository.createClientRequestId();
    }
    setState(() => _renaming = true);
    try {
      await ref
          .read(ipAccountRepositoryProvider)
          .rename(
            account.id,
            title,
            revision: account.revision,
            requestId: _renameRequestId!,
            cancelToken: token,
          );
      if (!mounted ||
          token.isCancelled ||
          ref.read(userProvider)?.id != owner) {
        return;
      }
      ref.invalidate(projectsProvider);
      AppToast.success(context, l10n.ipAccountSaved);
      await _load();
    } catch (_) {
      if (mounted &&
          !token.isCancelled &&
          ref.read(userProvider)?.id == owner) {
        AppToast.error(context, l10n.networkRequestFailed);
      }
    } finally {
      if (mounted && !token.isCancelled) setState(() => _renaming = false);
    }
  }

  void _dismissRenameConfirmation() {
    if (!_confirmingRename) return;
    _confirmingRename = false;
    Navigator.of(context, rootNavigator: true).pop(false);
  }

  Future<void> _edit({bool positioning = false}) async {
    final account = _account;
    if (account == null || !account.editable) return;
    final owner = ref.read(userProvider)?.id;
    final token = _token!;
    final l10n = AppLocalizations.of(context)!;
    final saved = await AppSheet.show<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => AccountPreferencesSheet(
        account: account,
        editScope: positioning
            ? AccountPreferencesEditScope.positioning
            : AccountPreferencesEditScope.preferences,
      ),
    );
    if (!mounted ||
        token.isCancelled ||
        saved == null ||
        ref.read(userProvider)?.id != owner) {
      return;
    }
    ref.invalidate(projectsProvider);
    AppToast.success(context, l10n.ipAccountSaved);
    await _load();
  }

  Future<void> _startContent() async {
    final account = _account;
    if (account == null || !account.editable || _creating || _bindingLoading) {
      return;
    }
    final token = _token!;
    final owner = ref.read(userProvider)?.id;
    setState(() => _creating = true);
    try {
      if (_bindingFailed) await _loadBinding(account, token);
      if (!mounted ||
          token.isCancelled ||
          ref.read(userProvider)?.id != owner ||
          _bindingFailed) {
        return;
      }
      final bound = _boundSession;
      if (bound == null) throw StateError('Account session is unavailable');
      await context.push(
        Uri(
          path: '/session',
          queryParameters: {'sessionId': bound.id},
        ).toString(),
      );
      if (mounted && !token.isCancelled) await _load();
    } catch (_) {
      if (mounted &&
          !token.isCancelled &&
          ref.read(userProvider)?.id == owner) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.networkRequestFailed,
        );
      }
    } finally {
      if (mounted && identical(_token, token)) {
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      _dismissRenameConfirmation();
      _creating = false;
      unawaited(_load());
    });
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final insets = ref.watch(safeAreaInsetsProvider);
    final account = _account;
    final guest = ref.watch(userProvider) == null;
    return Scaffold(
      backgroundColor: colors.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: colors.brightness == Brightness.light
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEDE9FD), Colors.white],
                )
              : null,
          color: colors.brightness == Brightness.dark ? colors.surface : null,
        ),
        child: Column(
          children: [
            AppGlassHeader(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: math.max(
                      52,
                      math.max(
                        insets.top,
                        MediaQuery.viewPaddingOf(context).top,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 15),
                        IconButton(
                          key: const Key('ip-account-home-back'),
                          tooltip: l10n.back,
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/ip-accounts'),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 21),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.ipAccountHomeTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: guest
                  ? Center(
                      child: FilledButton(
                        onPressed: () => context.push('/login'),
                        child: Text(l10n.goToLogin),
                      ),
                    )
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failed || account == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.ipAccountLoadFailed,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(onPressed: _load, child: Text(l10n.retry)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        key: const Key('ip-account-home-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          20 +
                              math.max(
                                0,
                                (MediaQuery.sizeOf(context).width - 640) / 2,
                              ),
                          10,
                          20 +
                              math.max(
                                0,
                                (MediaQuery.sizeOf(context).width - 640) / 2,
                              ),
                          20,
                        ),
                        children: [
                          _summary(account, l10n),
                          const SizedBox(height: 20),
                          _section(
                            l10n.ipAccountPreferences,
                            onEdit: account.editable ? () => _edit() : null,
                            editKey: 'ip-account-edit-preferences',
                            children: [
                              _field(
                                l10n.ipContentDirection,
                                account.preferenceText('contentDirections'),
                                l10n,
                              ),
                              _field(
                                l10n.ipAudienceFeeling,
                                account.preferenceText('audienceFeelings'),
                                l10n,
                              ),
                              _field(
                                l10n.ipPresentation,
                                account.preferenceText('presentationFormats'),
                                l10n,
                              ),
                              _field(
                                l10n.ipTargetAudience,
                                account.preferenceText('targetAudience'),
                                l10n,
                              ),
                              _field(
                                l10n.accountConstraints,
                                account.preferenceText('creativeConstraints'),
                                l10n,
                                last: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _section(
                            l10n.accountUserPrompt,
                            onEdit: account.editable
                                ? () => _edit(positioning: true)
                                : null,
                            editKey: 'ip-account-edit-positioning',
                            children: [
                              Text(
                                account.userPrompt.isEmpty
                                    ? l10n.ipAccountFieldEmpty
                                    : account.userPrompt,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          IpAccountHistory(
                            creations: _history,
                            loading: _historyLoading,
                            onOpen: _openHistory,
                            onOpenAll: _showHistory,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: guest || account == null
          ? null
          : DecoratedBox(
              key: const Key('ip-account-publish-panel'),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(45),
              ),
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: math.max(20, insets.bottom)),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    (MediaQuery.sizeOf(context).width < 360 ? 20 : 40) +
                        math.max(
                          0,
                          (MediaQuery.sizeOf(context).width - 640) / 2,
                        ),
                    20,
                    (MediaQuery.sizeOf(context).width < 360 ? 20 : 40) +
                        math.max(
                          0,
                          (MediaQuery.sizeOf(context).width - 640) / 2,
                        ),
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        account.editable
                            ? l10n.ipAccountPublish
                            : l10n.ipAccountUnavailable,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.ipAccountPublishReady,
                        style: const TextStyle(fontSize: 16, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        key: const Key('ip-account-start-content'),
                        onPressed:
                            account.editable && !_creating && !_bindingLoading
                            ? _startContent
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          visualDensity: VisualDensity.standard,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: _creating || _bindingLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _boundSession == null
                                    ? l10n.ipAccountStartContent
                                    : l10n.ipAccountContinueConversation,
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _summary(IpAccountHome account, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAccountIcon(
                key: ValueKey('ip-account-icon-${account.id}'),
                backgroundColor: account.iconBackgroundColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final title = Text(
                          account.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                        final badge = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            l10n.ipAccountProfile,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        );
                        if (constraints.maxWidth < 250 ||
                            MediaQuery.textScalerOf(context).scale(12) > 15) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, const SizedBox(height: 5), badge],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 10),
                            badge,
                          ],
                        );
                      },
                    ),
                    if (account.description.isNotEmpty)
                      Text(
                        account.description,
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.ipAccountNickname, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 5),
          AppExpandedTextField(
            fieldKey: const Key('ip-account-edit-nickname'),
            controller: _nicknameController,
            focusNode: _nicknameFocus,
            hint: l10n.ipNicknameHint,
            limit: AccountInputLimits.nicknameCharacters,
            maxBytes: AccountInputLimits.nicknameBytes,
            nickname: true,
            editInSheet: false,
            readOnly: !account.editable || _renaming || _confirmingRename,
            onSubmitted: (_) => _saveNickname(),
            trailing: IconButton(
              key: const Key('ip-account-save-nickname'),
              tooltip: l10n.ipAccountSave,
              onPressed: account.editable && !_renaming && !_confirmingRename
                  ? _saveNickname
                  : null,
              icon: _renaming
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.check_circle, size: 28, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white.withValues(alpha: .65)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: child,
  );

  Widget _section(
    String title, {
    required List<Widget> children,
    VoidCallback? onEdit,
    String? editKey,
  }) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onEdit != null)
              TextButton(
                key: Key(editKey!),
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  minimumSize: const Size(97, 40),
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotatedBox(
                      quarterTurns: 1,
                      child: AppSvgIcon.asset(
                        'ip_account_edit',
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(AppLocalizations.of(context)!.ipAccountEdit),
                  ],
                ),
              ),
          ],
        ),
        const Divider(height: 30),
        ...children,
      ],
    ),
  );

  Widget _field(
    String label,
    String value,
    AppLocalizations l10n, {
    bool last = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Text(
        value.isEmpty ? l10n.ipAccountFieldEmpty : value,
        style: const TextStyle(fontSize: 16, height: 1.4),
      ),
      if (!last) const Divider(height: 30),
    ],
  );
}
