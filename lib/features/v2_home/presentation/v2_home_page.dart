import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_assets/presentation/v2_assets_page.dart';
import '../../v2_session/presentation/v2_chat_page.dart';
import 'v2_welcome_page.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';

class V2HomePage extends StatefulWidget {
  const V2HomePage({required this.repository, super.key});
  final V2Repository repository;
  @override
  State<V2HomePage> createState() => _V2HomePageState();
}

class _V2HomePageState extends State<V2HomePage> {
  int _tab = 0;
  bool _bottomVisible = true;
  String _query = '';

  bool _onScroll(Notification notification) {
    if (notification is ScrollMetricsNotification &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.maxScrollExtent <=
            notification.metrics.minScrollExtent) {
      _showBottom(true);
    } else if (notification is UserScrollNotification &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.direction != ScrollDirection.idle) {
      _showBottom(notification.direction == ScrollDirection.forward);
    }
    return false;
  }

  void _showBottom(bool visible) {
    if (visible != _bottomVisible) {
      setState(() => _bottomVisible = visible);
    }
  }

  void _open(V2Session s) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            V2ChatPage(repository: widget.repository, sessionId: s.id),
      ),
    );
  }

  void _profile() => context.push('/profile');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return V2Scaffold(
      floatingBottom: true,
      floatingBottomVisible: _bottomVisible,
      title: Text(_tab == 0 ? l.demoConversations : l.demoAssets),
      leading: IconButton(
        tooltip: l.demoProfile,
        padding: EdgeInsets.zero,
        onPressed: _profile,
        icon: const V2Avatar(size: 40),
      ),
      actions: [
        IconButton(
          key: const Key('demo-create'),
          tooltip: _tab == 0 ? l.demoNew : l.demoUpload,
          onPressed: () => _tab == 0
              ? Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        V2WelcomePage(repository: widget.repository),
                  ),
                )
              : showV2Import(context, widget.repository),
          icon: _tab == 0
              ? const V2Icon('plus', color: AppColors.brand)
              : const V2Icon('upload', size: 24, color: AppColors.brand),
        ),
      ],
      bottom: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            heightFactor: 1,
            child: ClipRRect(
              key: const Key('demo-bottom-tabs'),
              borderRadius: BorderRadius.circular(27),
              child: BackdropFilter(
                key: const Key('demo-bottom-tabs-glass'),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 144,
                  height: 54,
                  padding: const EdgeInsets.all(5),
                  color: v2Surface(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Semantics(
                          selected: _tab == i,
                          child: Container(
                            decoration: ShapeDecoration(
                              color: _tab == i ? v2Tint : Colors.transparent,
                              shape: const CircleBorder(),
                            ),
                            child: IconButton(
                              key: Key('demo-tab-$i'),
                              tooltip: i == 0
                                  ? l.demoConversations
                                  : l.demoAssets,
                              onPressed: () => setState(() => _tab = i),
                              icon: V2Icon(
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
      child: NotificationListener<Notification>(
        onNotification: _onScroll,
        child: IndexedStack(
          index: _tab,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: V2Search(
                    hint: l.demoSearchHistory,
                    onChanged: (q) => setState(() {
                      _query = q;
                      _bottomVisible = true;
                    }),
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: widget.repository,
                    builder: (context, _) {
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
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final s = sessions[index];
                          return AppContextMenu(
                            key: ValueKey(s.id),
                            label: s.title,
                            entries: [
                              AppMenuItem(
                                label: l.renameProjectItem,
                                icon: const Icon(Icons.edit_outlined),
                                onSelected: () => v2EditText(
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
                                    await v2Perform(
                                      context,
                                      () =>
                                          widget.repository.deleteSession(s.id),
                                    );
                                  }
                                },
                              ),
                            ],
                            child: Material(
                              color: index == 0 && _query.isEmpty
                                  ? v2Tint
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _open(s),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    12,
                                    10,
                                  ),
                                  child: Row(
                                    children: [
                                      V2Avatar(
                                        members: s.members,
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
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      if (s.id != 'campus') ...[
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 9,
                                                                vertical: 3,
                                                              ),
                                                          decoration:
                                                              const ShapeDecoration(
                                                                color: v2Tint,
                                                                shape:
                                                                    StadiumBorder(),
                                                              ),
                                                          child: Text(
                                                            switch (s.kind) {
                                                              V2SessionKind
                                                                  .conversation =>
                                                                l.demoConversation,
                                                              V2SessionKind
                                                                  .project =>
                                                                l.demoProject,
                                                              V2SessionKind
                                                                  .workflow =>
                                                                l.demoWorkflow,
                                                            },
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  s.kind ==
                                                                      V2SessionKind
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
                                                    color:
                                                        AppColors.textTertiary,
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
                                                      fontSize: 16,
                                                      color: AppColors
                                                          .textSecondary,
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
                                                          color:
                                                              AppColors.brand,
                                                          shape:
                                                              BoxShape.circle,
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
            V2AssetsView(repository: widget.repository),
          ],
        ),
      ),
    );
  }
}
