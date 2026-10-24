import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../../core/network/network_api.dart';
import '../../../../core/storage/gallery_image_storage.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/network_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_glass_app_bar.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../data/session_artifact_exporter.dart';
import '../../data/session_artifact_repository.dart';
import '../../domain/session_artifact.dart';
import '../../data/session_repository.dart';
import 'conversation_timeline.dart' show MarkdownMessage, ConversationMediaView;

/// Conversation outputs and their details share one sheet navigation stack.
class SessionArtifactsSheet extends ConsumerStatefulWidget {
  const SessionArtifactsSheet({
    this.sessionId,
    this.repository,
    this.mediaRepository,
    super.key,
  });

  final String? sessionId;
  final SessionArtifactRepository? repository;
  final SessionRepository? mediaRepository;

  static Future<void> show(
    BuildContext context, {
    String? sessionId,
    SessionRepository? mediaRepository,
  }) => AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
    ),
    builder: (_) => SessionArtifactsSheet(
      sessionId: sessionId,
      mediaRepository: mediaRepository,
    ),
  );

  @override
  ConsumerState<SessionArtifactsSheet> createState() =>
      _SessionArtifactsSheetState();
}

class _SessionArtifactsSheetState extends ConsumerState<SessionArtifactsSheet> {
  final _listController = ScrollController();
  List<SessionArtifact>? _items;
  SessionArtifactType? _filter;
  SessionArtifact? _selected;
  CancelToken? _loadToken;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SessionArtifactsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.repository != widget.repository) {
      _selected = null;
      _items = null;
      _load();
    }
  }

  Future<void> _load() async {
    _loadToken?.cancel();
    final token = _loadToken = CancelToken();
    try {
      final repository =
          widget.repository ??
          ApiSessionArtifactRepository(
            NetworkApi(ref.read(dioProvider)),
            cancelToken: token,
          );
      final items = await repository.list(widget.sessionId);
      if (mounted && !token.isCancelled) {
        setState(() => _items = items);
      }
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() => _items ??= const []);
      AppToast.error(context, AppLocalizations.of(context)!.chatRequestFailed);
    }
  }

  @override
  void dispose() {
    _loadToken?.cancel();
    _listController.dispose();
    super.dispose();
  }

  void _back() => setState(() => _selected = null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
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
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 21,
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
                            if (SessionArtifactExporter.supports(selected))
                              _DownloadButton(
                                item: selected,
                                repository: widget.mediaRepository,
                              )
                            else
                              const SizedBox(width: 40),
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
                          repository: selected.mediaId == null
                              ? null
                              : widget.mediaRepository ??
                                    ref.read(sessionRepositoryProvider),
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
                    repository: widget.mediaRepository,
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
      SessionArtifactType.audio => l10n.sessionArtifactAudioDetail,
    };

String _artifactMetadata(SessionArtifact item, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final material = MaterialLocalizations.of(context);
  final createdAt = item.createdAt?.toLocal();
  return [
    if (item.textKind != null) ...[
      switch (item.textKind) {
        'topic' => l10n.chatTextTopic,
        'storyboard' => l10n.chatTextStoryboard,
        _ => l10n.chatTextScript,
      },
      if ((item.durationSeconds ?? 0) > 0)
        l10n.roleDurationSeconds(item.durationSeconds.toString())
      else
        l10n.chatTextUnknownDuration,
    ] else ...[
      if (item.type == SessionArtifactType.image)
        l10n.images
      else if (item.type == SessionArtifactType.video)
        l10n.videos
      else if (item.metadata.trim().isNotEmpty)
        item.metadata.trim(),
      if ((item.sizeBytes ?? 0) > 0) _artifactFileSize(item.sizeBytes!),
    ],
    if (createdAt != null)
      '${material.formatCompactDate(createdAt)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
  ].join(' · ');
}

String _artifactFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

class _DownloadButton extends ConsumerStatefulWidget {
  const _DownloadButton({
    required this.item,
    this.inList = false,
    this.repository,
  });

  final SessionArtifact item;
  final bool inList;
  final SessionRepository? repository;

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  bool _saving = false;
  CancelToken? _downloadToken;

  Future<void> _download() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    if (!SessionArtifactExporter.supports(widget.item)) {
      AppToast.info(context, l10n.assetDownloadUnavailable);
      return;
    }
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final token = _downloadToken = CancelToken();
    final isDocument = widget.item.type == SessionArtifactType.script;
    setState(() => _saving = true);
    try {
      final saved = await SessionArtifactExporter.save(
        widget.item,
        sharePositionOrigin: origin,
        repository: widget.item.mediaId == null
            ? null
            : widget.repository ?? ref.read(sessionRepositoryProvider),
        imageConfiguration: createLocalImageConfiguration(context),
        cancelToken: token,
      );
      if (mounted && !token.isCancelled && saved) {
        AppToast.success(
          context,
          isDocument ? l10n.sessionArtifactExported : l10n.sessionArtifactSaved,
        );
      }
    } catch (error) {
      if (mounted && !token.isCancelled) {
        final denied =
            error is GalleryAccessDenied ||
            error is GalException &&
                error.type == GalExceptionType.accessDenied;
        AppToast.error(
          context,
          denied
              ? (widget.item.type == SessionArtifactType.video
                    ? l10n.videoSaveAccessDenied
                    : l10n.imageSaveAccessDenied)
              : isDocument
              ? l10n.sessionArtifactExportFailed
              : l10n.sessionArtifactSaveFailed,
        );
      }
    } finally {
      _downloadToken = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _downloadToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filled = !widget.inList;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        key: ValueKey(
          'session-artifact-download-${widget.inList ? widget.item.id : 'detail'}',
        ),
        tooltip: AppLocalizations.of(context)!.download,
        style: IconButton.styleFrom(
          backgroundColor: filled
              ? colors.primary
              : colors.primary.withValues(alpha: .05),
          shape: filled
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _saving ? null : _download,
        icon: _saving
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? colors.onPrimary : colors.primary,
                ),
              )
            : AppSvgIcon.asset(
                'session_artifact_download',
                size: 18,
                color: filled ? colors.onPrimary : colors.primary,
              ),
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.item,
    required this.onOpen,
    this.repository,
    super.key,
  });

  final SessionArtifact item;
  final VoidCallback onOpen;
  final SessionRepository? repository;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = item.summary.trim();
    final metadata = _artifactMetadata(item, context).trim();
    final icon = switch (item.type) {
      SessionArtifactType.image => 'session_artifact_image',
      SessionArtifactType.script => 'session_artifact_script',
      SessionArtifactType.video => 'session_artifact_video',
      SessionArtifactType.audio => null,
    };
    return Material(
      key: ValueKey('session-artifact-${item.id}'),
      color: colors.brightness == Brightness.dark
          ? colors.surfaceContainerLow
          : Colors.white.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon == null)
                    Icon(
                      Icons.audiotrack_outlined,
                      size: 20,
                      color: colors.onSurface,
                    )
                  else
                    AppSvgIcon.asset(icon, size: 20, color: colors.onSurface),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (SessionArtifactExporter.supports(item)) ...[
                    _DownloadButton(
                      item: item,
                      inList: true,
                      repository: repository,
                    ),
                    const SizedBox(width: 8),
                  ],
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
              if (item.previewAsset != null ||
                  summary.isNotEmpty ||
                  metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.previewAsset != null) ...[
                      SizedBox.square(
                        dimension: 58,
                        child: _ArtifactImage(
                          asset: item.previewAsset!,
                          radius: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (summary.isNotEmpty)
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.3,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          if (summary.isNotEmpty && metadata.isNotEmpty)
                            const SizedBox(height: 5),
                          if (metadata.isNotEmpty)
                            Text(
                              metadata,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: .65,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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

/// Opens the exact saved output without looking up a creation archive.
class SessionArtifactDetailPage extends ConsumerWidget {
  const SessionArtifactDetailPage({
    required this.item,
    this.actions = const [],
    super.key,
  });

  final SessionArtifact item;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    return Scaffold(
      appBar: AppGlassAppBar(
        extendBackdrop: false,
        child: AppBar(
          title: Text(_detailTitle(AppLocalizations.of(context)!, item.type)),
          actions: [
            ...actions,
            if (SessionArtifactExporter.supports(item))
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _DownloadButton(item: item),
              ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _ArtifactDetail(
          item: item,
          repository: item.mediaId == null
              ? null
              : ref.read(sessionRepositoryProvider),
        ),
      ),
    );
  }
}

class _ArtifactDetail extends StatefulWidget {
  const _ArtifactDetail({required this.item, this.repository, super.key});

  final SessionArtifact item;
  final SessionRepository? repository;

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
          _artifactMetadata(item, context),
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurfaceVariant.withValues(alpha: .65),
          ),
        ),
        const SizedBox(height: 20),
        if (item.mediaId != null) ...[
          ConversationMediaView(
            id: item.mediaId!,
            repository: widget.repository!,
            result: true,
          ),
          const SizedBox(height: 20),
        ],
        if (item.mediaId == null && item.type == SessionArtifactType.image) ...[
          AspectRatio(
            aspectRatio: 1,
            child: _ArtifactImage(asset: item.previewAsset!),
          ),
          const SizedBox(height: 20),
        ],
        if (item.mediaId == null && item.type == SessionArtifactType.video) ...[
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
        if (item.textKind != null)
          MarkdownMessage(text: item.summary)
        else
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
