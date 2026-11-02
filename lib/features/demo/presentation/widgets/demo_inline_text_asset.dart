import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_menu.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../session/data/session_artifact_exporter.dart';
import '../../../session/domain/session_artifact.dart';
import '../../data/demo_media_exporter.dart';
import '../../data/demo_repository.dart';
import '../../domain/demo_models.dart';
import '../demo_assets_page.dart';

/// Shows plain-text attachments as selectable source without interpreting them.
class DemoInlineTextAsset extends StatefulWidget {
  const DemoInlineTextAsset({
    required this.assets,
    required this.repository,
    required this.expanded,
    required this.onExpandedChanged,
    this.active = true,
    this.onLoadError,
    super.key,
  }) : assert(assets.length > 0);

  final List<DemoAsset> assets;
  final DemoRepository repository;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final bool active;
  final VoidCallback? onLoadError;

  static bool supports(DemoAsset asset) {
    if (asset.kind != DemoAssetKind.script || asset.isDocument) return false;
    final mimeType = asset.mimeType.split(';').first.trim().toLowerCase();
    if (mimeType == 'text/plain' || mimeType == 'text/markdown') return true;
    return !asset.isRemote &&
        asset.mimeType.trim().isEmpty &&
        asset.body.isNotEmpty;
  }

  /// Groups equivalent TXT/Markdown representations at their first position.
  static List<List<DemoAsset>> groupAttachments(List<DemoAsset> assets) {
    final groups = <List<DemoAsset>>[];
    final textGroupIndexes = <String, int>{};
    for (final asset in assets) {
      final key = supports(asset) ? _equivalentTextKey(asset) : null;
      final existingIndex = key == null ? null : textGroupIndexes[key];
      if (existingIndex != null) {
        groups[existingIndex].add(asset);
        continue;
      }
      groups.add([asset]);
      if (key != null) textGroupIndexes[key] = groups.length - 1;
    }
    return groups;
  }

  static String? _equivalentTextKey(DemoAsset asset) {
    final sha256 = asset.sha256.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) || asset.sizeBytes <= 0) {
      return null;
    }
    final stem = asset.title
        .trim()
        .replaceFirst(RegExp(r'\.(?:txt|md)$', caseSensitive: false), '')
        .trim()
        .toLowerCase();
    if (stem.isEmpty) return null;
    return '$stem\u0000$sha256\u0000${asset.sizeBytes}';
  }

  static String _fileName(DemoAsset asset) {
    final title = asset.title.trim().isEmpty ? asset.id : asset.title.trim();
    final mimeType = asset.mimeType.split(';').first.trim().toLowerCase();
    final extension = switch (mimeType) {
      'text/plain' => 'txt',
      'text/markdown' => 'md',
      _ => '',
    };
    return extension.isEmpty || title.toLowerCase().endsWith('.$extension')
        ? title
        : '$title.$extension';
  }

  static String _downloadMenuLabel(DemoAsset asset) {
    final mimeType = asset.mimeType.split(';').first.trim().toLowerCase();
    final format = switch (mimeType) {
      'text/plain' => 'TXT',
      'text/markdown' => 'Markdown',
      _ => '',
    };
    final fileName = _fileName(asset);
    return format.isEmpty ? fileName : '$format · $fileName';
  }

  @override
  State<DemoInlineTextAsset> createState() => _DemoInlineTextAssetState();
}

class _DemoInlineTextAssetState extends State<DemoInlineTextAsset> {
  static const _previewCodePoints = 1500;
  static const _previewLines = 12;
  static const _chunkCodePoints = 1024;

  late String _body;
  late bool _loading;
  final Set<String> _savingAssetIds = {};
  bool _loadErrorShown = false;
  int _loadEpoch = 0;

  DemoAsset get _primary => widget.assets.first;

  @override
  void initState() {
    super.initState();
    _resetBody();
    if (_loading && widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant DemoInlineTextAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPrimary = oldWidget.assets.first;
    if (!identical(oldWidget.repository, widget.repository) ||
        !_sameSource(oldPrimary, _primary)) {
      _loadEpoch += 1;
      _resetBody();
      _savingAssetIds.clear();
      if (_loading && widget.active) unawaited(_load());
      return;
    }
    if (oldWidget.active && !widget.active) {
      _loadEpoch += 1;
    } else if (!oldWidget.active && widget.active && _loading) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _loadEpoch += 1;
    super.dispose();
  }

  bool _sameSource(DemoAsset left, DemoAsset right) =>
      left.id == right.id &&
      left.body == right.body &&
      left.contentUrl == right.contentUrl &&
      left.mimeType == right.mimeType &&
      left.sha256 == right.sha256 &&
      left.sizeBytes == right.sizeBytes;

  void _resetBody() {
    _body = _primary.body;
    _loading = _body.isEmpty;
    _loadErrorShown = false;
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    final asset = _primary;
    try {
      final body = await widget.repository.readAssetText(asset);
      if (!mounted || !widget.active || epoch != _loadEpoch) return;
      setState(() {
        _body = body;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || !widget.active || epoch != _loadEpoch) return;
      setState(() => _loading = false);
      if (!_loadErrorShown) {
        _loadErrorShown = true;
        final onLoadError = widget.onLoadError;
        if (onLoadError != null) {
          onLoadError();
        } else {
          AppToast.error(
            context,
            AppLocalizations.of(context)!.demoAssetLoadFailed,
          );
        }
      }
    }
  }

  Future<void> _copy() async {
    if (_body.isEmpty || !widget.active) return;
    await Clipboard.setData(ClipboardData(text: _body));
    if (mounted && widget.active) {
      AppToast.success(
        context,
        AppLocalizations.of(context)!.demoInlineTextCopied,
      );
    }
  }

  Future<void> _save(DemoAsset asset) async {
    if (!widget.active || _savingAssetIds.contains(asset.id)) return;
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : Rect.zero;
    setState(() => _savingAssetIds.add(asset.id));
    try {
      final saved = asset.isRemote
          ? await DemoMediaExporter.save(
              asset,
              origin,
              readBytes: () => widget.repository.readAssetBytes(asset),
            )
          : await SessionArtifactExporter.save(
              SessionArtifact(
                id: asset.id,
                type: SessionArtifactType.script,
                title: asset.title,
                summary: asset.body,
                metadata: '',
                textKind: 'script',
              ),
              sharePositionOrigin: origin,
            );
      if (mounted && widget.active && saved) {
        AppToast.success(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaved,
        );
      }
    } catch (_) {
      if (mounted && widget.active) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _savingAssetIds.remove(asset.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final panelColor = theme.brightness == Brightness.dark
        ? colors.surfaceContainerHigh
        : const Color(0xFFF2F2F3);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: DecoratedBox(
        key: ValueKey('demo-inline-text-${primary.id}'),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .55),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Divider(height: 1, thickness: 1, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: _buildBody(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final primary = _primary;
    final primaryFileName = DemoInlineTextAsset._fileName(primary);
    final busy = _savingAssetIds.isNotEmpty;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l.demoInlineTextOpenFile(primaryFileName),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('demo-inline-text-open-${primary.id}'),
                  onTap: widget.active
                      ? () => openDemoAsset(
                          context,
                          primary,
                          repository: widget.repository,
                        )
                      : null,
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, size: 19),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              primaryFileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
          IconButton(
            key: ValueKey('demo-inline-text-copy-${primary.id}'),
            tooltip: l.copyAction,
            onPressed: widget.active && !_loading && _body.isNotEmpty
                ? _copy
                : null,
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
          if (widget.assets.length == 1)
            IconButton(
              key: ValueKey('demo-inline-text-download-${primary.id}'),
              tooltip: l.download,
              onPressed: widget.active && !busy ? () => _save(primary) : null,
              icon: _savingAssetIds.contains(primary.id)
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
            )
          else
            AppMenuButton(
              key: ValueKey('demo-inline-text-downloads-${primary.id}'),
              tooltip: l.demoInlineTextDownloadFormats,
              enabled: widget.active,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
              entries: [
                for (final asset in widget.assets)
                  AppMenuItem(
                    key: ValueKey('demo-inline-text-download-${asset.id}'),
                    label: DemoInlineTextAsset._downloadMenuLabel(asset),
                    enabled: !_savingAssetIds.contains(asset.id),
                    onSelected: () => unawaited(_save(asset)),
                    icon: _savingAssetIds.contains(asset.id)
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                  ),
              ],
            ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final primary = _primary;
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return AppSkeleton(
        key: ValueKey('demo-inline-text-loading-${primary.id}'),
        label: l.demoInlineTextLoading,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeletonBox(height: 17),
            SizedBox(height: 9),
            AppSkeletonBox(height: 17),
            SizedBox(height: 9),
            FractionallySizedBox(
              widthFactor: .72,
              alignment: Alignment.centerLeft,
              child: AppSkeletonBox(height: 17),
            ),
          ],
        ),
      );
    }
    if (_body.isEmpty) return const SizedBox(height: 1);
    return widget.expanded
        ? _ExpandedRawText(
            key: ValueKey('demo-inline-text-content-${primary.id}'),
            assetId: primary.id,
            text: _body,
            onCollapse: widget.active
                ? () => widget.onExpandedChanged(false)
                : null,
          )
        : _CollapsedRawText(
            key: ValueKey('demo-inline-text-content-${primary.id}'),
            assetId: primary.id,
            text: _body,
            previewCodePoints: _previewCodePoints,
            maxLines: _previewLines,
            onExpand: widget.active
                ? () => widget.onExpandedChanged(true)
                : null,
          );
  }
}

class _CollapsedRawText extends StatelessWidget {
  const _CollapsedRawText({
    required this.assetId,
    required this.text,
    required this.previewCodePoints,
    required this.maxLines,
    required this.onExpand,
    super.key,
  });

  final String assetId;
  final String text;
  final int previewCodePoints;
  final int maxLines;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final previewRunes = text.runes.take(previewCodePoints).toList();
    final preview = String.fromCharCodes(previewRunes);
    final truncatedByLength = preview.length < text.length;
    const style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      height: 1.55,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: preview, style: style),
          maxLines: maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final exceededLines = painter.didExceedMaxLines;
        painter.dispose();
        final canExpand = truncatedByLength || exceededLines;
        final rawText = Text(
          preview,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: style,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectionContainer.maybeOf(context) == null
                ? SelectionArea(child: rawText)
                : rawText,
            if (canExpand) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                key: ValueKey('demo-inline-text-expand-$assetId'),
                onPressed: onExpand,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.demoInlineTextExpand),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ExpandedRawText extends StatefulWidget {
  const _ExpandedRawText({
    required this.assetId,
    required this.text,
    required this.onCollapse,
    super.key,
  });

  final String assetId;
  final String text;
  final VoidCallback? onCollapse;

  @override
  State<_ExpandedRawText> createState() => _ExpandedRawTextState();
}

class _ExpandedRawTextState extends State<_ExpandedRawText> {
  late List<int> _chunkOffsets = _buildChunkOffsets(widget.text);
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ExpandedRawText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _chunkOffsets = _buildChunkOffsets(widget.text);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(
      420.0,
      math.max(220.0, MediaQuery.sizeOf(context).height * .45),
    );
    final list = ListView.builder(
      key: ValueKey('demo-inline-text-scroll-${widget.assetId}'),
      controller: _scrollController,
      primary: false,
      padding: const EdgeInsets.only(right: 14, bottom: 20),
      itemCount: _chunkOffsets.length - 1,
      itemBuilder: (context, index) => Text(
        widget.text.substring(_chunkOffsets[index], _chunkOffsets[index + 1]),
        key: ValueKey('demo-inline-text-chunk-${widget.assetId}-$index'),
        softWrap: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SelectionContainer.maybeOf(context) == null
                ? SelectionArea(child: list)
                : list,
          ),
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Padding(
          key: ValueKey('demo-inline-text-footer-${widget.assetId}'),
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.demoInlineTextScrollHint,
                key: ValueKey('demo-inline-text-scroll-hint-${widget.assetId}'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ValueKey('demo-inline-text-expand-${widget.assetId}'),
                  onPressed: widget.onCollapse,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.expand_less_rounded, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.demoInlineTextCollapse,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<int> _buildChunkOffsets(String value) {
    final offsets = <int>[0];
    var codeUnitOffset = 0;
    var codePointsInChunk = 0;
    for (final rune in value.runes) {
      codeUnitOffset += rune > 0xFFFF ? 2 : 1;
      codePointsInChunk += 1;
      if (codePointsInChunk == _DemoInlineTextAssetState._chunkCodePoints) {
        offsets.add(codeUnitOffset);
        codePointsInChunk = 0;
      }
    }
    if (offsets.last != value.length) offsets.add(value.length);
    return offsets;
  }
}
