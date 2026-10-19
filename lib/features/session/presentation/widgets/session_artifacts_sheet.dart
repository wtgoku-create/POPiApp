import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../data/session_artifact_repository.dart';
import '../../domain/session_artifact.dart';

/// Conversation outputs and their details share one sheet navigation stack.
class SessionArtifactsSheet extends StatefulWidget {
  const SessionArtifactsSheet({
    this.sessionId,
    this.repository = const SessionArtifactRepository(),
    super.key,
  });

  final String? sessionId;
  final SessionArtifactRepository repository;

  static Future<void> show(BuildContext context, {String? sessionId}) =>
      AppSheet.show<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
        ),
        builder: (_) => SessionArtifactsSheet(sessionId: sessionId),
      );

  @override
  State<SessionArtifactsSheet> createState() => _SessionArtifactsSheetState();
}

class _SessionArtifactsSheetState extends State<SessionArtifactsSheet> {
  final _listController = ScrollController();
  List<SessionArtifact>? _items;
  SessionArtifactType? _filter;
  SessionArtifact? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.list(widget.sessionId);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = const []);
      AppToast.error(context, AppLocalizations.of(context)!.chatRequestFailed);
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _back() => setState(() => _selected = null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final selected = _selected;
    return PopScope<void>(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selected != null) _back();
      },
      child: SizedBox(
        key: const Key('session-artifacts-sheet'),
        height: MediaQuery.sizeOf(context).height * AppSheet.maxHeightFactor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: selected == null
                      ? Center(
                          child: Text(
                            l10n.sessionArtifactsTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            IconButton(
                              key: const Key('session-artifact-back'),
                              tooltip: l10n.back,
                              onPressed: _back,
                              icon: AppSvgIcon.asset(
                                'activity_back',
                                size: 22,
                                color: colors.onSurface,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _detailTitle(l10n, selected.type),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const _DownloadButton(),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: IndexedStack(
                    index: selected == null ? 0 : 1,
                    children: [
                      _list(context),
                      if (selected == null)
                        const SizedBox.shrink()
                      else
                        _ArtifactDetail(
                          key: ValueKey(selected.id),
                          item: selected,
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
  }

  Widget _list(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final items = _items
        ?.where((item) => _filter == null || item.type == _filter)
        .toList();
    final filters = <SessionArtifactType?, String>{
      null: l10n.sessionArtifactAll,
      SessionArtifactType.image: l10n.sessionArtifactRoles,
      SessionArtifactType.script: l10n.sessionArtifactScripts,
      SessionArtifactType.video: l10n.sessionArtifactVideos,
    };
    return Column(
      children: [
        Row(
          children: [
            for (final entry in filters.entries)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    key: ValueKey(
                      'session-artifact-filter-${entry.key?.name ?? 'all'}',
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: _filter == entry.key
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      backgroundColor: _filter == entry.key
                          ? colors.primary.withValues(alpha: .05)
                          : Colors.transparent,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      setState(() => _filter = entry.key);
                      if (_listController.hasClients) _listController.jumpTo(0);
                    },
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _filter == entry.key
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: items == null
              ? AppSkeletonList(label: l10n.sessionArtifactsTitle, itemCount: 3)
              : items.isEmpty
              ? Center(child: Text(l10n.sessionArtifactsEmpty))
              : ListView.separated(
                  controller: _listController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ArtifactCard(
                    key: ValueKey(items[index].id),
                    item: items[index],
                    onOpen: () => setState(() => _selected = items[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

String _detailTitle(AppLocalizations l10n, SessionArtifactType type) =>
    switch (type) {
      SessionArtifactType.image => l10n.sessionArtifactImageDetail,
      SessionArtifactType.script => l10n.sessionArtifactScriptDetail,
      SessionArtifactType.video => l10n.sessionArtifactVideoDetail,
    };

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final filled = id == null;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        key: ValueKey('session-artifact-download-${id ?? 'detail'}'),
        tooltip: l10n.download,
        style: IconButton.styleFrom(
          backgroundColor: filled
              ? colors.primary
              : colors.primary.withValues(alpha: .05),
          shape: filled
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => AppToast.info(context, l10n.assetDownloadUnavailable),
        icon: AppSvgIcon.asset(
          'session_artifact_download',
          size: 18,
          color: filled ? colors.onPrimary : colors.primary,
        ),
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({required this.item, required this.onOpen, super.key});

  final SessionArtifact item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (item.type) {
      SessionArtifactType.image => 'session_artifact_image',
      SessionArtifactType.script => 'session_artifact_script',
      SessionArtifactType.video => 'session_artifact_video',
    };
    return Container(
      key: ValueKey('session-artifact-${item.id}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainerLow
            : Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSvgIcon.asset(icon, size: 20, color: colors.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _DownloadButton(id: item.id),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  key: ValueKey('session-artifact-open-${item.id}'),
                  tooltip: _detailTitle(
                    AppLocalizations.of(context)!,
                    item.type,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary.withValues(alpha: .05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onOpen,
                  icon: AppSvgIcon.asset(
                    'session_artifact_open',
                    size: 18,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.previewAsset != null) ...[
                SizedBox.square(
                  dimension: 58,
                  child: _ArtifactImage(asset: item.previewAsset!, radius: 10),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.metadata,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant.withValues(alpha: .65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtifactImage extends StatelessWidget {
  const _ArtifactImage({required this.asset, this.radius = 20});

  final String asset;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: ColoredBox(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
      child: Image.asset(asset, fit: BoxFit.contain),
    ),
  );
}

class _ArtifactDetail extends StatefulWidget {
  const _ArtifactDetail({required this.item, super.key});

  final SessionArtifact item;

  @override
  State<_ArtifactDetail> createState() => _ArtifactDetailState();
}

class _ArtifactDetailState extends State<_ArtifactDetail> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: ValueKey('session-artifact-detail-${item.id}'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          item.metadata,
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurfaceVariant.withValues(alpha: .65),
          ),
        ),
        const SizedBox(height: 20),
        if (item.type == SessionArtifactType.image) ...[
          AspectRatio(
            aspectRatio: 1,
            child: _ArtifactImage(asset: item.previewAsset!),
          ),
          const SizedBox(height: 20),
        ],
        if (item.type == SessionArtifactType.video) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _playing
                ? AppVideoPlayer(
                    url: item.videoUrl!,
                    autoplay: true,
                    controlsKeyPrefix: 'session-artifact-video',
                  )
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(item.previewAsset!, fit: BoxFit.cover),
                        Center(
                          child: IconButton.filledTonal(
                            key: const Key('session-artifact-video-play'),
                            tooltip: AppLocalizations.of(context)!.videoPlay,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black38,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => setState(() => _playing = true),
                            icon: const Icon(Icons.play_arrow, size: 32),
                          ),
                        ),
                        const Positioned(
                          right: 16,
                          bottom: 12,
                          child: Text(
                            '00:00/00:32',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: [Shadow(blurRadius: 4)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          item.summary,
          style: TextStyle(
            fontSize: item.type == SessionArtifactType.script ? 16 : 14,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
        for (final shot in item.shots) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                shot.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                shot.time,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant.withValues(alpha: .65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            shot.description,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            shot.audio,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
