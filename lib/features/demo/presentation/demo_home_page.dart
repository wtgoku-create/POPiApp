import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/providers/local_profile_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../profile/presentation/widgets/profile_chrome.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'demo_assets_page.dart';
import 'demo_chat_page.dart';
import 'demo_create_session_sheet.dart';
import 'demo_desktop_workspace.dart';
import 'widgets/demo_widgets.dart';

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({required this.repository, super.key});
  final DemoRepository repository;
  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage>
    with WidgetsBindingObserver {
  int _tab = 0;
  String _query = '';
  Future<void>? _refreshInFlight;
  bool _openingSession = false;

  @override
  void initState() {
    super.initState();
    if (widget.repository.isHarness) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_refreshHarness(reportError: true));
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.repository.isHarness) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshHarness());
    }
  }

  Future<void> _refreshHarness({bool reportError = false}) {
    if (!widget.repository.isHarness || !mounted) return Future.value();
    if (ModalRoute.of(context)?.isCurrent == false) return Future.value();
    return _refreshInFlight ??= _performHarnessRefresh(
      reportError: reportError,
    );
  }

  Future<void> _performHarnessRefresh({required bool reportError}) async {
    try {
      if (reportError) {
        await demoPerform(context, widget.repository.refreshSessions);
      } else {
        try {
          await widget.repository.refreshSessions();
        } catch (_) {
          // Automatic synchronization keeps the last good snapshot visible.
        }
      }
    } finally {
      _refreshInFlight = null;
    }
  }

  void _selectTab(int tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    unawaited(_refreshHarness());
  }

  Future<void> _open(DemoSession s) async {
    if (_openingSession) return;
    _openingSession = true;
    try {
      final pendingRefresh = _refreshInFlight;
      if (pendingRefresh != null) await pendingRefresh;
      if (!mounted) return;
      final current = widget.repository.sessions
          .where((session) => session.id == s.id)
          .firstOrNull;
      if (current == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DemoChatPage(
            repository: widget.repository,
            sessionId: current.id,
          ),
        ),
      );
      if (mounted) await _refreshHarness();
    } finally {
      _openingSession = false;
    }
  }

  void _profile() => context.push('/profile');

  Future<void> _startCreate() async {
    final l = AppLocalizations.of(context)!;
    final id = await showDemoCreateSessionSheet(
      context: context,
      repository: widget.repository,
      initialTitle: l.demoNew,
      kind: DemoSessionKind.conversation,
    );
    if (id == null || !mounted) return;
    await _open(widget.repository.session(id));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            (!kIsWeb && Theme.of(context).platform == TargetPlatform.macOS) ||
            (kIsWeb && constraints.maxWidth >= 900);
        return desktop
            ? DemoDesktopWorkspace(repository: widget.repository)
            : _buildMobile(context);
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DemoScaffold(
      floatingBottom: true,
      frostedBottom: _tab == 0,
      actionsPadding: 16,
      title: Text(
        _tab == 0 ? l.demoConversations : l.demoAssets,
        style: _tab == 1
            ? const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)
            : null,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: SizedBox.square(
            dimension: 40,
            child: IconButton(
              tooltip: l.demoProfile,
              padding: EdgeInsets.zero,
              onPressed: _profile,
              icon: Consumer(
                builder: (context, ref, _) {
                  final user = ref.watch(userProvider);
                  final bytes = user == null
                      ? ref.watch(localProfileProvider)?.avatarBytes
                      : null;
                  return ProfileAvatar(
                    size: 36,
                    imageUrl: user?.avatarUrl,
                    imageProvider: bytes == null ? null : MemoryImage(bytes),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (_tab == 0)
          IconButton(
            key: const Key('demo-create'),
            tooltip: l.demoNew,
            onPressed: _startCreate,
            icon: const DemoIcon('plus', color: AppColors.brand),
          )
        else
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              key: const Key('demo-create'),
              tooltip: l.demoUpload,
              padding: EdgeInsets.zero,
              onPressed: () => showDemoImport(context, widget.repository),
              icon: Container(
                width: 36,
                height: 36,
                decoration: const ShapeDecoration(
                  color: demoTint,
                  shape: CircleBorder(),
                ),
                child: const Center(
                  child: DemoIcon('upload', size: 20, color: AppColors.brand),
                ),
              ),
            ),
          ),
      ],
      bottom: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            heightFactor: 1,
            child: ClipRRect(
              key: const Key('demo-bottom-tabs'),
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                key: const Key('demo-bottom-tabs-glass'),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 152,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: ShapeDecoration(
                    color: demoSurface(context),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Semantics(
                          selected: _tab == i,
                          child: Container(
                            decoration: ShapeDecoration(
                              color: _tab == i ? demoTint : Colors.transparent,
                              shape: const CircleBorder(),
                            ),
                            child: IconButton(
                              key: Key('demo-tab-$i'),
                              tooltip: i == 0
                                  ? l.demoConversations
                                  : l.demoAssets,
                              onPressed: () => _selectTab(i),
                              icon: DemoIcon(
                                i == 0 ? 'chat' : 'folder',
                                color: _tab == i
                                    ? AppColors.brand
                                    : AppColors.textSecondary,
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
        ),
      ),
      child: IndexedStack(
        index: _tab,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: DemoSearch(
                  hint: l.demoSearchHistory,
                  onChanged: (q) => setState(() => _query = q),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.repository,
                  builder: (context, _) {
                    if (widget.repository.loading &&
                        widget.repository.sessions.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final sessions = widget.repository.sessions
                        .where(
                          (s) =>
                              '${s.title} ${s.messages.lastOrNull?.text ?? ''}'
                                  .toLowerCase()
                                  .contains(_query.trim().toLowerCase()),
                        )
                        .toList();
                    if (sessions.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? l.demoEmptyConversations
                              : l.demoNoResults,
                        ),
                      );
                    }
                    return ListView.separated(
                      key: const PageStorageKey('demo-conversations'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final s = sessions[index];
                        return AppContextMenu(
                          key: ValueKey(s.id),
                          label: s.title,
                          entries: [
                            AppMenuItem(
                              key: const Key('demo-session-pin'),
                              label: s.pinned
                                  ? l.demoUnpinSession
                                  : l.demoPinSession,
                              icon: Icon(
                                s.pinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                              ),
                              onSelected: () => demoPerform(
                                context,
                                () => widget.repository.updateSession(
                                  s.id,
                                  (session) =>
                                      session.copyWith(pinned: !session.pinned),
                                ),
                              ),
                            ),
                            AppMenuItem(
                              label: l.renameProjectItem,
                              icon: const Icon(Icons.edit_outlined),
                              onSelected: () => demoEditText(
                                context,
                                title: l.demoRename,
                                label: l.demoSessionName,
                                value: s.title,
                                onSave: (title) =>
                                    widget.repository.updateSession(
                                      s.id,
                                      (s) => s.copyWith(title: title),
                                    ),
                              ),
                            ),
                            const AppMenuDivider(),
                            AppMenuItem(
                              label: l.delete,
                              destructive: true,
                              icon: const Icon(Icons.delete_outline),
                              onSelected: () async {
                                final yes = await AppDialog.confirm(
                                  context: context,
                                  title: l.delete,
                                  description: l.demoDeleteDescription,
                                  cancelLabel: l.cancel,
                                  confirmLabel: l.confirm,
                                  destructive: true,
                                );
                                if (yes == true && context.mounted) {
                                  await demoPerform(
                                    context,
                                    () => widget.repository.deleteSession(s.id),
                                  );
                                }
                              },
                            ),
                          ],
                          child: Material(
                            color: index == 0 && _query.isEmpty
                                ? demoTint
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _open(s),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                                child: Row(
                                  children: [
                                    DemoAvatar(
                                      members: s.members,
                                      size: 60,
                                      memberAvatars: s.memberAvatars,
                                      memberColors: s.memberColors,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        s.title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (s.id != 'campus') ...[
                                                      const SizedBox(width: 5),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 9,
                                                              vertical: 3,
                                                            ),
                                                        decoration:
                                                            const ShapeDecoration(
                                                              color: demoTint,
                                                              shape:
                                                                  StadiumBorder(),
                                                            ),
                                                        child: Text(
                                                          switch (s.kind) {
                                                            DemoSessionKind
                                                                .conversation =>
                                                              l.demoConversation,
                                                            DemoSessionKind
                                                                .project =>
                                                              l.demoProject,
                                                            DemoSessionKind
                                                                .workflow =>
                                                              l.demoWorkflow,
                                                          },
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                s.kind ==
                                                                    DemoSessionKind
                                                                        .conversation
                                                                ? AppColors
                                                                      .textPrimary
                                                                : AppColors
                                                                      .brand,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                s.time.isEmpty
                                                    ? l.demoNow
                                                    : s.time,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  s.messages.lastOrNull?.text
                                                          .replaceAll(
                                                            '\n',
                                                            ' ',
                                                          ) ??
                                                      l.demoGreetingDetail,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              if (s.unread > 0)
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  alignment: Alignment.center,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: AppColors.brand,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Text(
                                                    '${s.unread}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                    );
                  },
                ),
              ),
            ],
          ),
          DemoAssetsView(repository: widget.repository),
        ],
      ),
    );
  }
}
