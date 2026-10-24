import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_menu.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../domain/demo_models.dart';
import 'demo_widgets.dart';

/// Conversation navigation used by the wide desktop workspace.
class DemoDesktopSidebar extends StatefulWidget {
  const DemoDesktopSidebar({
    required this.sessions,
    required this.selectedSessionId,
    required this.expanded,
    required this.onSelectSession,
    required this.onCreate,
    required this.onAssets,
    required this.onProfile,
    required this.onSearch,
    required this.profileAvatar,
    this.assetsSelected = false,
    this.query = '',
    this.sessionMenuBuilder,
    super.key,
  });

  final List<DemoSession> sessions;
  final String? selectedSessionId;
  final bool expanded;
  final ValueChanged<DemoSession> onSelectSession;
  final VoidCallback onCreate;
  final VoidCallback onAssets;
  final VoidCallback onProfile;
  final ValueChanged<String> onSearch;
  final Widget profileAvatar;
  final bool assetsSelected;
  final String query;
  final List<AppMenuEntry> Function(DemoSession)? sessionMenuBuilder;

  @override
  State<DemoDesktopSidebar> createState() => _DemoDesktopSidebarState();
}

class _DemoDesktopSidebarState extends State<DemoDesktopSidebar> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.query,
  );
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearch = false;

  @override
  void didUpdateWidget(DemoDesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _searchController.text != widget.query) {
      _searchController.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
    if (!oldWidget.expanded && widget.expanded && widget.query.isNotEmpty) {
      _showSearch = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    if (!widget.expanded) {
      _showCompactSearch();
      return;
    }
    setState(() => _showSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _showCompactSearch() => AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    maxHeightFraction: .34,
    builder: (context) => _CompactSearchSheet(
      initialQuery: widget.query,
      onChanged: widget.onSearch,
    ),
  );

  void _clearOrCloseSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      widget.onSearch('');
      return;
    }
    setState(() => _showSearch = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final background = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLow
        : const Color(0xFFF7F7F8);
    return DecoratedBox(
      key: const Key('demo-desktop-sidebar'),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withValues(alpha: .55)),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _SidebarHeader(
              expanded: widget.expanded,
              searching: _showSearch,
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSearchPressed: _openSearch,
              onSearchChanged: widget.onSearch,
              onSearchClosed: _clearOrCloseSearch,
              onCreate: widget.onCreate,
              searchTooltip: l.searchConversations,
              createTooltip: l.demoNew,
            ),
            Expanded(
              child: _SessionList(
                sessions: widget.sessions,
                selectedSessionId: widget.selectedSessionId,
                expanded: widget.expanded,
                query: widget.query,
                onSelectSession: widget.onSelectSession,
                sessionMenuBuilder: widget.sessionMenuBuilder,
                emptySummary: l.demoGreetingDetail,
              ),
            ),
            const Divider(height: 1),
            _SidebarFooter(
              expanded: widget.expanded,
              assetsSelected: widget.assetsSelected,
              onAssets: widget.onAssets,
              onProfile: widget.onProfile,
              profileAvatar: widget.profileAvatar,
              assetsLabel: l.demoAssets,
              profileLabel: l.demoProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.expanded,
    required this.searching,
    required this.controller,
    required this.focusNode,
    required this.onSearchPressed,
    required this.onSearchChanged,
    required this.onSearchClosed,
    required this.onCreate,
    required this.searchTooltip,
    required this.createTooltip,
  });

  final bool expanded;
  final bool searching;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSearchPressed;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClosed;
  final VoidCallback onCreate;
  final String searchTooltip;
  final String createTooltip;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            _SidebarIconButton(
              key: const Key('demo-desktop-search'),
              tooltip: searchTooltip,
              onPressed: onSearchPressed,
              icon: const DemoIcon('search', size: 20),
            ),
            const SizedBox(height: 4),
            _SidebarIconButton(
              key: const Key('demo-desktop-create'),
              tooltip: createTooltip,
              onPressed: onCreate,
              icon: const DemoIcon('plus', size: 20),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: searching
                ? SizedBox(
                    height: 42,
                    child: TextField(
                      key: const Key('demo-desktop-search-field'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: searchTooltip,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(11),
                          child: DemoIcon('search', size: 18),
                        ),
                        suffixIcon: IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: onSearchClosed,
                          icon: const DemoIcon('close', size: 16),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _SidebarIconButton(
                      key: const Key('demo-desktop-search'),
                      tooltip: searchTooltip,
                      onPressed: onSearchPressed,
                      icon: const DemoIcon('search', size: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          _SidebarIconButton(
            key: const Key('demo-desktop-create'),
            tooltip: createTooltip,
            onPressed: onCreate,
            icon: const DemoIcon('plus', size: 20),
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.selectedSessionId,
    required this.expanded,
    required this.query,
    required this.onSelectSession,
    required this.sessionMenuBuilder,
    required this.emptySummary,
  });

  final List<DemoSession> sessions;
  final String? selectedSessionId;
  final bool expanded;
  final String query;
  final ValueChanged<DemoSession> onSelectSession;
  final List<AppMenuEntry> Function(DemoSession)? sessionMenuBuilder;
  final String emptySummary;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final visibleSessions = normalizedQuery.isEmpty
        ? sessions
        : sessions
              .where((session) {
                final summary = session.messages.lastOrNull?.text ?? '';
                return '${session.title} $summary'.toLowerCase().contains(
                  normalizedQuery,
                );
              })
              .toList(growable: false);

    return ListView.builder(
      key: const PageStorageKey('demo-desktop-sessions'),
      padding: EdgeInsets.fromLTRB(expanded ? 10 : 8, 2, expanded ? 10 : 8, 12),
      itemExtent: expanded ? 66 : 56,
      itemCount: visibleSessions.length,
      itemBuilder: (context, index) {
        final session = visibleSessions[index];
        final selected = session.id == selectedSessionId;
        final summary =
            session.messages.lastOrNull?.text.replaceAll('\n', ' ').trim() ??
            '';
        final tile = Semantics(
          selected: selected,
          button: true,
          label: session.title,
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelectSession(session),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 10 : 8,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    DemoAvatar(
                      members: session.members,
                      size: 40,
                      memberAvatars: session.memberAvatars,
                      memberColors: session.memberColors,
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              summary.isEmpty ? emptySummary : summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
        final menus =
            sessionMenuBuilder?.call(session) ?? const <AppMenuEntry>[];
        return AppContextMenu(
          key: Key('demo-desktop-session-${session.id}'),
          label: session.title,
          entries: menus,
          enabled: menus.isNotEmpty,
          child: expanded ? tile : Tooltip(message: session.title, child: tile),
        );
      },
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.expanded,
    required this.assetsSelected,
    required this.onAssets,
    required this.onProfile,
    required this.profileAvatar,
    required this.assetsLabel,
    required this.profileLabel,
  });

  final bool expanded;
  final bool assetsSelected;
  final VoidCallback onAssets;
  final VoidCallback onProfile;
  final Widget profileAvatar;
  final String assetsLabel;
  final String profileLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(expanded ? 12 : 8, 10, expanded ? 12 : 8, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SidebarDestination(
          key: const Key('demo-desktop-assets'),
          expanded: expanded,
          selected: assetsSelected,
          label: assetsLabel,
          onPressed: onAssets,
          icon: const DemoIcon('folder', size: 21),
        ),
        const SizedBox(height: 6),
        _SidebarDestination(
          key: const Key('demo-desktop-profile'),
          expanded: expanded,
          selected: false,
          label: profileLabel,
          onPressed: onProfile,
          icon: SizedBox.square(dimension: 38, child: profileAvatar),
        ),
      ],
    ),
  );
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.expanded,
    required this.selected,
    required this.label,
    required this.onPressed,
    required this.icon,
    super.key,
  });

  final bool expanded;
  final bool selected;
  final String label;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? demoTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Tooltip(
          message: label,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 5),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  icon,
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 42,
    child: IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: icon,
    ),
  );
}

class _CompactSearchSheet extends StatefulWidget {
  const _CompactSearchSheet({
    required this.initialQuery,
    required this.onChanged,
  });

  final String initialQuery;
  final ValueChanged<String> onChanged;

  @override
  State<_CompactSearchSheet> createState() => _CompactSearchSheetState();
}

class _CompactSearchSheetState extends State<_CompactSearchSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.searchConversations,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('demo-desktop-search-field'),
            controller: _controller,
            autofocus: true,
            onChanged: widget.onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.demoSearchHistory,
              prefixIcon: const Padding(
                padding: EdgeInsets.all(13),
                child: DemoIcon('search', size: 18),
              ),
              suffixIcon: IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                icon: const DemoIcon('close', size: 16),
              ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
