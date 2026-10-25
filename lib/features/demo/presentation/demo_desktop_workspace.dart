import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/local_profile_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/type/menu_type.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../profile/presentation/widgets/profile_chrome.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'demo_assistant_display.dart';
import 'demo_assets_page.dart';
import 'demo_chat_page.dart';
import 'demo_create_session_sheet.dart';
import 'widgets/demo_desktop_sidebar.dart';
import 'widgets/demo_widgets.dart';

/// The persistent two-pane shell used by macOS and wide web windows.
class DemoDesktopWorkspace extends StatefulWidget {
  const DemoDesktopWorkspace({required this.repository, super.key});

  final DemoRepository repository;

  @override
  State<DemoDesktopWorkspace> createState() => _DemoDesktopWorkspaceState();
}

class _DemoDesktopWorkspaceState extends State<DemoDesktopWorkspace> {
  final _detailNavigatorKey = GlobalKey<NavigatorState>();
  final _stageRevision = ValueNotifier<int>(0);
  final List<String> _openedSessionIds = [];
  List<String> _knownSessionIds = const [];
  String? _selectedSessionId;
  String _query = '';
  bool _assetsSelected = false;
  int _assetRouteRevision = 0;
  bool _workspaceActive = true;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_repositoryChanged);
    _synchronizeSessions(notify: false);
  }

  @override
  void didUpdateWidget(covariant DemoDesktopWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository == widget.repository) return;
    oldWidget.repository.removeListener(_repositoryChanged);
    widget.repository.addListener(_repositoryChanged);
    _openedSessionIds.clear();
    _knownSessionIds = const [];
    _selectedSessionId = null;
    _synchronizeSessions(notify: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = ModalRoute.of(context)?.isCurrent != false;
    if (_workspaceActive == active) return;
    _workspaceActive = active;
    _stageRevision.value += 1;
  }

  @override
  void dispose() {
    widget.repository.removeListener(_repositoryChanged);
    _stageRevision.dispose();
    super.dispose();
  }

  void _repositoryChanged() => _synchronizeSessions(notify: true);

  void _synchronizeSessions({required bool notify}) {
    final sessions = widget.repository.sessions;
    final nextIds = sessions.map((session) => session.id).toList();
    var nextSelected = _selectedSessionId;
    final selectedWasRemoved =
        nextSelected != null && !nextIds.contains(nextSelected);

    if (selectedWasRemoved) {
      final oldIndex = _knownSessionIds.indexOf(nextSelected);
      nextSelected = nextIds.isEmpty
          ? null
          : nextIds[oldIndex < 0
                ? 0
                : oldIndex.clamp(0, nextIds.length - 1).toInt()];
    }
    nextSelected ??= nextIds.firstOrNull;

    void apply() {
      _knownSessionIds = nextIds;
      _openedSessionIds.removeWhere((id) => !nextIds.contains(id));
      _selectedSessionId = nextSelected;
      if (nextSelected != null && !_openedSessionIds.contains(nextSelected)) {
        _openedSessionIds.add(nextSelected);
      }
      _stageRevision.value += 1;
    }

    if (notify && mounted) {
      if (selectedWasRemoved && !_assetsSelected) {
        _detailNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
      setState(apply);
    } else {
      apply();
    }
  }

  void _selectSession(DemoSession session) {
    FocusManager.instance.primaryFocus?.unfocus();
    _detailNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _assetRouteRevision += 1;
      _assetsSelected = false;
      _selectedSessionId = session.id;
      if (!_openedSessionIds.contains(session.id)) {
        _openedSessionIds.add(session.id);
      }
      _stageRevision.value += 1;
    });
  }

  Future<void> _startCreate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final sheetContext = _detailNavigatorKey.currentContext;
    if (sheetContext == null || !sheetContext.mounted) return;
    final id = await showDemoCreateSessionSheet(
      context: sheetContext,
      repository: widget.repository,
      kind: DemoSessionKind.conversation,
    );
    if (id == null || !mounted) return;
    final session = widget.repository.sessions
        .where((session) => session.id == id)
        .firstOrNull;
    if (session != null) _selectSession(session);
  }

  Future<void> _openAssets() async {
    if (_assetsSelected) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = _detailNavigatorKey.currentState;
    if (navigator == null) return;
    final routeRevision = ++_assetRouteRevision;
    setState(() => _assetsSelected = true);
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return DemoScaffold(
            title: Text(l.demoAssets),
            actions: [
              IconButton(
                key: const Key('demo-desktop-upload'),
                tooltip: l.demoUpload,
                onPressed: () => showDemoImport(context, widget.repository),
                icon: const DemoIcon('upload', color: AppColors.brand),
              ),
            ],
            child: DemoAssetsView(repository: widget.repository),
          );
        },
      ),
    );
    if (mounted && routeRevision == _assetRouteRevision) {
      setState(() => _assetsSelected = false);
    }
  }

  List<AppMenuEntry> _sessionMenu(DemoSession session) {
    final l = AppLocalizations.of(context)!;
    return [
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
          final confirmed = await AppDialog.confirm(
            context: context,
            title: l.delete,
            description: l.demoDeleteDescription,
            cancelLabel: l.cancel,
            confirmLabel: l.confirm,
            destructive: true,
          );
          if (confirmed == true && mounted) {
            await demoPerform(
              context,
              () => widget.repository.deleteSession(session.id),
            );
          }
        },
      ),
    ];
  }

  Widget _profileAvatar() => Consumer(
    builder: (context, ref, _) {
      final user = ref.watch(userProvider);
      final bytes = user == null
          ? ref.watch(localProfileProvider)?.avatarBytes
          : null;
      return ProfileAvatar(
        size: 38,
        imageUrl: user?.avatarUrl,
        imageProvider: bytes == null ? null : MemoryImage(bytes),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 1000;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              SizedBox(
                key: const Key('demo-desktop-sidebar-frame'),
                width: expanded ? 280 : 80,
                child: DemoDesktopSidebar(
                  sessions: widget.repository.sessions,
                  selectedSessionId: _selectedSessionId,
                  expanded: expanded,
                  onSelectSession: _selectSession,
                  onCreate: _startCreate,
                  onAssets: _openAssets,
                  onProfile: () => context.push('/profile'),
                  onSearch: (query) => setState(() => _query = query),
                  profileAvatar: _profileAvatar(),
                  assetsSelected: _assetsSelected,
                  query: _query,
                  sessionMenuBuilder: _sessionMenu,
                ),
              ),
              Expanded(
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: Navigator(
                    key: _detailNavigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => ValueListenableBuilder<int>(
                        valueListenable: _stageRevision,
                        builder: (context, _, child) => _DesktopSessionStage(
                          repository: widget.repository,
                          openedSessionIds: List.of(_openedSessionIds),
                          selectedSessionId: _selectedSessionId,
                          workspaceActive: _workspaceActive,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopSessionStage extends StatelessWidget {
  const _DesktopSessionStage({
    required this.repository,
    required this.openedSessionIds,
    required this.selectedSessionId,
    required this.workspaceActive,
  });

  final DemoRepository repository;
  final List<String> openedSessionIds;
  final String? selectedSessionId;
  final bool workspaceActive;

  @override
  Widget build(BuildContext context) {
    if (openedSessionIds.isEmpty || selectedSessionId == null) {
      return const ColoredBox(
        color: AppColors.profileBackground,
        child: SizedBox.expand(),
      );
    }
    final selectedIndex = openedSessionIds.indexOf(selectedSessionId!);
    return IndexedStack(
      key: const Key('demo-desktop-chats'),
      index: selectedIndex < 0 ? 0 : selectedIndex,
      children: [
        for (final id in openedSessionIds)
          _DesktopChatHost(
            key: ValueKey('demo-desktop-chat-$id'),
            repository: repository,
            sessionId: id,
            active: workspaceActive && id == selectedSessionId,
          ),
      ],
    );
  }
}

class _DesktopChatHost extends StatelessWidget {
  const _DesktopChatHost({
    required this.repository,
    required this.sessionId,
    required this.active,
    super.key,
  });

  final DemoRepository repository;
  final String sessionId;
  final bool active;

  @override
  Widget build(BuildContext context) => FocusScope(
    canRequestFocus: active,
    child: TickerMode(
      enabled: active,
      child: DemoChatPage(
        repository: repository,
        sessionId: sessionId,
        desktopLayout: true,
        active: active,
      ),
    ),
  );
}
