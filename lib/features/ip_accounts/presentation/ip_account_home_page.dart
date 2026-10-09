import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/ip_account_provider.dart';
import '../../../shared/providers/project_provider.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/session_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../assets/domain/library_role.dart';
import '../../assets/presentation/role_detail_page.dart';
import '../../projects/data/project_repository.dart';
import '../domain/ip_account_home.dart';
import 'widgets/ip_account_edit_sheet.dart';
import 'widgets/ip_account_roles_sheet.dart';

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
  String? _renameTitle;
  String? _renameRequestId;
  CancelToken? _token;
  IpAccountHome? _account;
  IpAccountResources? _resources;
  bool _loading = true;
  bool _failed = false;
  bool _resourcesFailed = false;
  bool _creating = false;
  String? _creationRequestId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(IpAccountHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _creationRequestId = null;
      _creating = false;
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
      _resourcesFailed = false;
      _account = null;
      _resources = null;
      _creating = false;
      _renaming = false;
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
      await _loadResources(account, token);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadResources(IpAccountHome account, CancelToken token) async {
    setState(() {
      _resourcesFailed = false;
      _resources = null;
    });
    try {
      final resources = await ref
          .read(ipAccountRepositoryProvider)
          .resources(account, cancelToken: token);
      if (mounted && !token.isCancelled) setState(() => _resources = resources);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(() => _resourcesFailed = true);
      }
    }
  }

  Future<void> _saveNickname() async {
    final account = _account;
    final title = _nicknameController.text.trim();
    if (account == null || !account.editable || _renaming || title.isEmpty) {
      return;
    }
    if (title == account.title) {
      _nicknameFocus.unfocus();
      return;
    }
    final token = _token!;
    final owner = ref.read(userProvider)?.id;
    if (title != _renameTitle) {
      _renameTitle = title;
      _renameRequestId = ProjectRepository.createClientRequestId();
    }
    setState(() => _renaming = true);
    final l10n = AppLocalizations.of(context)!;
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

  Future<void> _edit({bool positioning = false}) async {
    final account = _account;
    if (account == null || !account.editable) return;
    final owner = ref.read(userProvider)?.id;
    final token = _token!;
    final l10n = AppLocalizations.of(context)!;
    final fields = positioning
        ? {'positioning': l10n.ipAccountPositioning}
        : {
            'contentDirection': l10n.ipContentDirection,
            'audienceFeeling': l10n.ipAudienceFeeling,
            'presentation': l10n.ipVisualStyle,
            'contentFormat': l10n.ipContentFormat,
            'targetAudience': l10n.ipTargetAudience,
          };
    final saved = await AppSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => IpAccountEditSheet(
        title: positioning
            ? l10n.ipAccountPositioning
            : l10n.ipAccountPreferences,
        fields: fields,
        values: {for (final field in fields.keys) field: account.text(field)},
        onSave: (values, requestId) async {
          if (ref.read(userProvider)?.id != owner || token.isCancelled) {
            throw StateError('Account changed');
          }
          final repository = ref.read(ipAccountRepositoryProvider);
          await repository.saveProfile(
            account,
            values,
            requestId: requestId,
            cancelToken: token,
          );
        },
      ),
    );
    if (!mounted || token.isCancelled || saved != true) return;
    ref.invalidate(projectsProvider);
    AppToast.success(context, l10n.ipAccountSaved);
    await _load();
  }

  Future<void> _manageRoles() async {
    final account = _account;
    if (account == null || !account.editable) return;
    final token = _token!;
    final owner = ref.read(userProvider)?.id;
    final saved = await AppSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => IpAccountRolesSheet(
        selectedNames: {
          for (final role in _resources?.roles ?? <LibraryRole>[])
            role.id: role.title,
        },
        selectedIds: [
          for (final role in account.residentRoles) role['roleId'].toString(),
        ],
        onSave: (ids, requestId) async {
          if (ref.read(userProvider)?.id != owner || token.isCancelled) {
            throw StateError('Account changed');
          }
          await ref
              .read(ipAccountRepositoryProvider)
              .saveRoles(
                account,
                ids,
                requestId: requestId,
                cancelToken: token,
              );
        },
      ),
    );
    if (mounted && !token.isCancelled && saved == true) await _load();
  }

  Future<void> _startContent() async {
    final account = _account;
    if (account == null || !account.editable || _creating) return;
    final token = _token!;
    final owner = ref.read(userProvider)?.id;
    final l10n = AppLocalizations.of(context)!;
    _creationRequestId ??= ProjectRepository.createClientRequestId();
    setState(() => _creating = true);
    try {
      final session = await ref
          .read(projectRepositoryProvider)
          .createSession(
            account.id,
            l10n.newSessionTitle,
            clientRequestId: _creationRequestId!,
            cancelToken: token,
          );
      if (!mounted ||
          token.isCancelled ||
          ref.read(userProvider)?.id != owner) {
        return;
      }
      _creationRequestId = null;
      ref.invalidate(projectSessionsProvider(account.id));
      ref.invalidate(sessionsProvider);
      setState(() => _creating = false);
      await context.push(
        Uri(
          path: '/session',
          queryParameters: {
            'sessionId': session.id,
            'prompt': l10n.ipAccountStartPrompt,
          },
        ).toString(),
      );
      if (mounted && !token.isCancelled) await _load();
    } catch (_) {
      if (mounted && !token.isCancelled) {
        AppToast.error(context, l10n.networkRequestFailed);
      }
    } finally {
      if (mounted && identical(_token, token)) {
        setState(() => _creating = false);
      }
    }
  }

  void _openRole(LibraryRole role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoleDetailPage(
          role: role,
          category: role.canEdit ? 'user' : 'official',
        ),
      ),
    );
  }

  void _showAssets() {
    final resources = _resources;
    if (resources == null) return;
    final l10n = AppLocalizations.of(context)!;
    final ownerId = ref.read(userProvider)?.id;
    AppSheet.showDraggable<void>(
      context: context,
      builder: (context, controller) => Consumer(
        builder: (context, ref, _) {
          ref.listen(userProvider.select((user) => user?.id), (_, id) {
            if (id != ownerId && context.mounted) Navigator.of(context).pop();
          });
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                l10n.ipAccountAssets,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (resources.creations.isEmpty) Text(l10n.ipAccountNoAssets),
              for (final creation in resources.creations)
                ListTile(
                  leading: const Icon(Icons.movie_outlined),
                  title: Text(creation.title),
                  trailing: creation.sessionId?.isNotEmpty == true
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: creation.sessionId?.isNotEmpty == true
                      ? () {
                          Navigator.of(context).pop();
                          this.context.push(
                            Uri(
                              path: '/session',
                              queryParameters: {
                                'sessionId': creation.sessionId!,
                              },
                            ).toString(),
                          );
                        }
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      _creationRequestId = null;
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
            SizedBox(
              height: math.max(
                52,
                math.max(insets.top, MediaQuery.viewPaddingOf(context).top),
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
                                account.text('contentDirection'),
                                l10n,
                              ),
                              _field(
                                l10n.ipAudienceFeeling,
                                account.text('audienceFeeling'),
                                l10n,
                              ),
                              _field(
                                l10n.ipPresentation,
                                [
                                  account.text('presentation'),
                                  account.text('contentFormat'),
                                ].where((s) => s.isNotEmpty).join(' x '),
                                l10n,
                              ),
                              _field(
                                l10n.ipTargetAudience,
                                account.text('targetAudience'),
                                l10n,
                                last: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _section(
                            l10n.ipAccountPositioning,
                            onEdit: account.editable
                                ? () => _edit(positioning: true)
                                : null,
                            editKey: 'ip-account-edit-positioning',
                            children: [
                              Text(
                                account.text('positioning').isEmpty
                                    ? l10n.ipAccountFieldEmpty
                                    : account.text('positioning'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_resourcesFailed)
                            _section(
                              l10n.ipAccountResourcesFailed,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _loadResources(account, _token!),
                                  child: Text(l10n.retry),
                                ),
                                if (account.editable)
                                  TextButton.icon(
                                    onPressed: _manageRoles,
                                    icon: const Icon(Icons.people_outline),
                                    label: Text(l10n.ipAccountManageRoles),
                                  ),
                              ],
                            )
                          else if (_resources == null)
                            const LinearProgressIndicator()
                          else ...[
                            _resourceSection(
                              title:
                                  '${l10n.ipAccountAssets}${l10n.ipAccountCountSeparator}${_resources!.creations.length}',
                              sectionKey: 'ip-account-assets-section',
                              openKey: 'ip-account-assets',
                              openLabel: l10n.ipAccountAssets,
                              onOpen: _showAssets,
                              emptyLabel: l10n.ipAccountAssetsEmptyPrompt,
                              addKey: 'ip-account-add-asset',
                              addLabel: l10n.ipAccountStartContent,
                              onAdd: account.editable && !_creating
                                  ? _startContent
                                  : null,
                              items: [
                                for (final creation in _resources!.creations)
                                  _creationTile(creation),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _resourceSection(
                              title:
                                  '${l10n.ipAccountRoles}${l10n.ipAccountCountSeparator}${_resources!.roles.length}',
                              sectionKey: 'ip-account-roles-section',
                              openKey: 'ip-account-roles',
                              openLabel: l10n.ipAccountManageRoles,
                              onOpen: account.editable ? _manageRoles : null,
                              emptyLabel: l10n.ipAccountRolesEmptyPrompt,
                              addKey: 'ip-account-manage-roles',
                              addLabel: l10n.ipAccountManageRoles,
                              onAdd: account.editable ? _manageRoles : null,
                              items: [
                                for (final role in _resources!.roles)
                                  _roleTile(role),
                              ],
                            ),
                          ],
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
                    math.max(20, insets.bottom),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 5,
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
                          Text(
                            l10n.ipAccountPublishEstimate,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.ipAccountPublishReady,
                        style: const TextStyle(fontSize: 16, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        key: const Key('ip-account-start-content'),
                        onPressed: account.editable && !_creating
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
                        child: _creating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.ipAccountStartContent,
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
              const AppSvgIcon.asset('ip_account_home_avatar', size: 50),
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
          Material(
            color: colors.primary.withValues(alpha: .05),
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ip-account-edit-nickname'),
                      controller: _nicknameController,
                      focusNode: _nicknameFocus,
                      readOnly: !account.editable || _renaming,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveNickname(),
                      decoration: InputDecoration(
                        hintText: l10n.ipNicknameHint,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    key: const Key('ip-account-save-nickname'),
                    tooltip: l10n.ipAccountSave,
                    onPressed: account.editable && !_renaming
                        ? _saveNickname
                        : null,
                    icon: _renaming
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.check_circle,
                            size: 20,
                            color: colors.primary,
                          ),
                  ),
                ],
              ),
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

  Widget _resourceSection({
    required String title,
    required String sectionKey,
    required String openKey,
    required String openLabel,
    required VoidCallback? onOpen,
    required String emptyLabel,
    required String addKey,
    required String addLabel,
    required VoidCallback? onAdd,
    required List<Widget> items,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key(sectionKey),
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.light
            ? Colors.white.withValues(alpha: .5)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                key: Key(openKey),
                tooltip: openLabel,
                onPressed: onOpen,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 20,
                  height: 20,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.standard,
                icon: const AppSvgIcon.asset('ip_account_chevron', size: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: items.isEmpty
                    ? Text(
                        emptyLabel,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: colors.primary.withValues(alpha: .3),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              items[i],
                            ],
                          ],
                        ),
                      ),
              ),
              if (onAdd != null) ...[
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    key: Key(addKey),
                    tooltip: addLabel,
                    onPressed: onAdd,
                    constraints: const BoxConstraints.tightFor(
                      width: 51.6,
                      height: 51.6,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.standard,
                    icon: AppSvgIcon.asset(
                      'ip_account_resource_add',
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _creationTile(IpAccountCreation creation) => Tooltip(
    message: creation.title,
    child: SizedBox.square(
      dimension: 51.6,
      child: Material(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _showAssets,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Center(
              child: Text(
                creation.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _roleTile(LibraryRole role) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
      child: const Center(child: Icon(Icons.person_outline, size: 24)),
    );
    return Tooltip(
      message: role.title,
      child: Semantics(
        label: role.title,
        button: true,
        child: SizedBox.square(
          dimension: 51.6,
          child: InkWell(
            onTap: () => _openRole(role),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: role.avatar.isEmpty
                  ? fallback
                  : Image.network(
                      role.avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
