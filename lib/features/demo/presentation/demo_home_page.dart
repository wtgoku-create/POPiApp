import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/launch_diagnostics.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/providers/local_profile_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../profile/presentation/widgets/profile_chrome.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'demo_assistant_display.dart';
import 'demo_assets_page.dart';
import 'demo_chat_page.dart';
import 'demo_create_session_sheet.dart';
import 'demo_desktop_workspace.dart';
import 'demo_session_list_presentation.dart';
import 'widgets/demo_conversation_list_item.dart';
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
  bool _searching = false;
  late final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Future<void>? _refreshInFlight;
  bool _openingSession = false;

  @override
  void initState() {
    super.initState();
    LaunchDiagnostics.mark(LaunchStage.homeInit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LaunchDiagnostics.mark(LaunchStage.homeFirstFrame);
    });
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
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    LaunchDiagnostics.mark(LaunchStage.refreshBegin);
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
      LaunchDiagnostics.mark(LaunchStage.refreshEnd);
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
      if (mounted) unawaited(_refreshHarness());
    } finally {
      _openingSession = false;
    }
  }

  void _profile() => context.push('/profile');

  Future<void> _startCreate() async {
    final id = await showDemoCreateSessionSheet(
      context: context,
      repository: widget.repository,
      kind: DemoSessionKind.conversation,
    );
    if (id == null || !mounted) return;
    await _open(widget.repository.session(id));
  }

  @override
  Widget build(BuildContext context) {
    LaunchDiagnostics.mark(LaunchStage.homeBuild);
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
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
        if (_tab == 0) ...[
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              key: const Key('demo-search-toggle'),
              tooltip: l.demoSearchHistory,
              padding: EdgeInsets.zero,
              onPressed: _toggleSearch,
              icon: DemoIcon(_searching ? 'close' : 'search', size: 20),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              key: const Key('demo-create'),
              tooltip: l.demoCreateAssistant,
              padding: EdgeInsets.zero,
              onPressed: _startCreate,
              icon: const DemoIcon('plus', size: 20),
            ),
          ),
        ] else
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
                  width: 236,
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
                    children: [
                      for (var i = 0; i < 2; i++)
                        Expanded(
                          child: Semantics(
                            selected: _tab == i,
                            button: true,
                            child: Material(
                              key: Key('demo-tab-$i'),
                              color: _tab == i ? demoTint : Colors.transparent,
                              shape: const StadiumBorder(),
                              child: InkWell(
                                customBorder: const StadiumBorder(),
                                onTap: () => _selectTab(i),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    DemoIcon(
                                      i == 0 ? 'chat' : 'folder',
                                      size: 20,
                                      color: _tab == i
                                          ? AppColors.brand
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        i == 0
                                            ? l.demoConversations
                                            : l.demoMaterials,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: _tab == i
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: _tab == i
                                              ? AppColors.brand
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
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
        ),
      ),
      child: IndexedStack(
        index: _tab,
        children: [
          _buildConversationInbox(context, l),
          DemoAssetsView(repository: widget.repository),
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_searching) {
        _searchController.clear();
        _query = '';
      }
      _searching = !_searching;
    });
    if (_searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  Widget _buildConversationInbox(
    BuildContext context,
    AppLocalizations l,
  ) => Column(
    children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: !_searching
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: DemoSearch(
                  key: const Key('demo-mobile-search'),
                  controller: _searchController,
                  hint: l.demoSearchHistory,
                  onChanged: (value) => setState(() => _query = value),
                  outlined: true,
                ),
              ),
      ),
      Expanded(
        child: ListenableBuilder(
          listenable: widget.repository,
          builder: (context, _) {
            if (widget.repository.loading &&
                widget.repository.sessions.isEmpty) {
              return AppSkeletonList(label: l.demoConversations);
            }
            final query = _query.trim().toLowerCase();
            final available = widget.repository.sessions;
            final sessions = query.isEmpty
                ? available
                : available
                      .where((session) {
                        final summary = DemoSessionListPresentation.fromSession(
                          session,
                          l,
                        ).summary;
                        return '${demoSessionDisplayName(l, session)} $summary'
                            .toLowerCase()
                            .contains(query);
                      })
                      .toList(growable: false);
            if (sessions.isEmpty) {
              return Center(
                child: Text(
                  query.isEmpty ? l.demoEmptyConversations : l.demoNoResults,
                ),
              );
            }
            final pinned = sessions.where((session) => session.pinned).toList();
            final recent = sessions
                .where((session) => !session.pinned)
                .toList();
            final entries = <({String? heading, DemoSession? session})>[
              if (pinned.isNotEmpty)
                (heading: l.demoPinnedConversations, session: null),
              for (final session in pinned) (heading: null, session: session),
              if (recent.isNotEmpty)
                (heading: l.demoRecentConversations, session: null),
              for (final session in recent) (heading: null, session: session),
            ];
            return ListView.builder(
              key: const PageStorageKey('demo-conversations'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final heading = entry.heading;
                if (heading != null) {
                  return Padding(
                    key: ValueKey('demo-session-section-$heading'),
                    padding: EdgeInsets.fromLTRB(4, index == 0 ? 8 : 22, 4, 4),
                    child: Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                final session = entry.session!;
                return AppContextMenu(
                  key: ValueKey(session.id),
                  label: demoSessionDisplayName(l, session),
                  entries: _sessionMenu(context, l, session),
                  child: DemoConversationListItem(
                    key: ValueKey('demo-session-${session.id}'),
                    session: session,
                    onTap: () => _open(session),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  List<AppMenuEntry> _sessionMenu(
    BuildContext context,
    AppLocalizations l,
    DemoSession session,
  ) => [
    AppMenuItem(
      key: const Key('demo-session-pin'),
      label: session.pinned ? l.demoUnpinSession : l.demoPinSession,
      icon: Icon(session.pinned ? Icons.push_pin : Icons.push_pin_outlined),
      onSelected: () => demoPerform(
        context,
        () => widget.repository.updateSession(
          session.id,
          (current) => current.copyWith(pinned: !current.pinned),
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
        value: demoSessionDisplayName(l, session),
        onSave: (title) => widget.repository.updateSession(
          session.id,
          (current) => current.copyWith(title: title),
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
            () => widget.repository.deleteSession(session.id),
          );
        }
      },
    ),
  ];
}
