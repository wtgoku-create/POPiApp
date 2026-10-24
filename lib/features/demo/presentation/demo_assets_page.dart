import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_media_preview.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../session/domain/session_artifact.dart';
import '../../session/presentation/widgets/session_artifacts_sheet.dart';
import '../data/demo_repository.dart';
import '../data/demo_file_picker.dart';
import '../data/demo_fixtures.dart';
import '../domain/demo_models.dart';
import '../domain/demo_upload_file.dart';
import 'widgets/demo_widgets.dart';
import 'widgets/demo_document_cover.dart';
import 'demo_audio_detail.dart';
import 'demo_file_import_sheet.dart';
import 'demo_script_detail_page.dart';
import 'demo_remote_media.dart';

String demoAssetMeta(
  AppLocalizations l,
  DemoAssetKind kind, {
  DemoAsset? asset,
}) {
  if (kind == DemoAssetKind.image && asset?.isRemote == true) {
    return asset!.width > 0 && asset.height > 0
        ? l.demoOwnedImageMeta(asset.width, asset.height)
        : l.demoImages;
  }
  if (kind == DemoAssetKind.video && asset?.isRemote == true) {
    final duration = asset!.durationSeconds > 0
        ? _demoDuration(asset.durationSeconds)
        : null;
    final dimensions = asset.width > 0 && asset.height > 0
        ? '${asset.width}×${asset.height}'
        : null;
    final details = <String>[l.demoVideos];
    if (duration != null) details.add(duration);
    if (dimensions != null) details.add(dimensions);
    return details.join(' / ');
  }
  if (asset?.isRemote == true && kind == DemoAssetKind.script) {
    return l.demoScripts;
  }
  if (asset?.isRemote == true && kind == DemoAssetKind.audio) {
    return asset!.durationSeconds > 0
        ? '${l.demoAudio} / ${_demoDuration(asset.durationSeconds)}'
        : l.demoAudio;
  }
  return switch (kind) {
    DemoAssetKind.image => l.demoReference,
    DemoAssetKind.video => l.demoVideoMeta,
    DemoAssetKind.script => l.demoScriptMeta,
    DemoAssetKind.audio => l.demoAudioMeta,
  };
}

String _demoDuration(double seconds) {
  final value = seconds.round().clamp(0, 359999);
  final hours = value ~/ 3600;
  final minutes = (value % 3600) ~/ 60;
  final remaining = value % 60;
  final clock =
      '${minutes.toString().padLeft(2, '0')}:'
      '${remaining.toString().padLeft(2, '0')}';
  return hours == 0 ? clock : '${hours.toString().padLeft(2, '0')}:$clock';
}

IconData demoAssetIcon(DemoAssetKind kind) => switch (kind) {
  DemoAssetKind.image => Icons.image_outlined,
  DemoAssetKind.video => Icons.videocam_outlined,
  DemoAssetKind.script => Icons.description_outlined,
  DemoAssetKind.audio => Icons.music_note_outlined,
};

Future<void> showDemoImport(
  BuildContext context,
  DemoRepository repository, {
  Future<List<DemoUploadFile>> Function()? pickFiles,
}) => DemoSheet.show<void>(
  context: context,
  builder: (_) => repository.isHarness
      ? DemoFileImportSheet(
          repository: repository,
          pickFiles: pickFiles ?? pickDemoAssetFiles,
        )
      : _ImportSheet(repository: repository),
);

class _ImportSheet extends StatefulWidget {
  const _ImportSheet({required this.repository});
  final DemoRepository repository;
  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  late final List<DemoAssetKind> _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.repository.isHarness
        ? <DemoAssetKind>[]
        : DemoAssetKind.values.toList();
  }

  void _selectSamples() {
    if (widget.repository.isHarness) {
      AppToast.info(context, AppLocalizations.of(context)!.chatUnavailable);
      return;
    }
    setState(() {
      for (final kind in DemoAssetKind.values) {
        if (!_selected.contains(kind)) _selected.add(kind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final examples = {
      for (final kind in DemoAssetKind.values)
        kind:
            widget.repository.assets.where((a) => a.kind == kind).firstOrNull ??
            DemoFixtures.assets().firstWhere((a) => a.kind == kind),
    };
    return PopScope(
      canPop: !_busy,
      child: DemoSheetBody(
        title: l.demoUpload,
        footer: DemoPrimaryButton(
          label: l.demoUploadLibrary,
          busy: _busy,
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  setState(() => _busy = true);
                  final ok = await demoPerform(
                    context,
                    () => widget.repository.importSamples(List.of(_selected)),
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                    AppToast.success(context, l.demoImported);
                  } else {
                    setState(() => _busy = false);
                  }
                },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              key: const Key('demo-import-picker'),
              color: demoTint,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _busy ? null : _selectSamples,
                child: SizedBox(
                  height: 126,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const DemoIcon(
                        'upload',
                        size: 32,
                        color: AppColors.brand,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l.demoSelectFiles,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l.demoFileTypes,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.demoSelectedFiles(_selected.length),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 110),
                itemCount: _selected.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final kind = _selected[i];
                  final asset = examples[kind]!;
                  return Container(
                    key: Key('demo-import-file-${kind.name}'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: demoSurface(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child:
                              kind == DemoAssetKind.script ||
                                  kind == DemoAssetKind.audio
                              ? Container(
                                  width: 50,
                                  height: 50,
                                  color: demoTint,
                                  child: Center(
                                    child: DemoIcon(
                                      kind.name,
                                      size: 24,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                )
                              : DemoAssetImage(
                                  asset: asset,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.title +
                                    switch (kind) {
                                      DemoAssetKind.image => '.png',
                                      DemoAssetKind.video => '.mp4',
                                      DemoAssetKind.script => '.md',
                                      DemoAssetKind.audio => '.mp4',
                                    },
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                demoAssetMeta(l, kind),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: Key('demo-import-remove-${kind.name}'),
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: l.delete,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _selected.remove(kind)),
                          icon: const DemoIcon(
                            'close',
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoAssetsView extends StatefulWidget {
  const DemoAssetsView({
    required this.repository,
    this.sessionId,
    this.onSelect,
    this.compactHeader = false,
    super.key,
  });
  final DemoRepository repository;
  final String? sessionId;
  final ValueChanged<DemoAsset>? onSelect;
  final bool compactHeader;
  @override
  State<DemoAssetsView> createState() => _DemoAssetsViewState();
}

class _DemoAssetsViewState extends State<DemoAssetsView> {
  int _filter = 0;
  bool _list = false;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final items = widget.repository.assets
            .where(
              (a) =>
                  (widget.sessionId == null ||
                      a.sessionId == widget.sessionId) &&
                  (_filter == 0 || a.kind.index == _filter - 1) &&
                  a.title.toLowerCase().contains(_query.trim().toLowerCase()),
            )
            .toList();
        return CustomScrollView(
          key: PageStorageKey(
            'demo-assets-${widget.sessionId}-${widget.onSelect != null}',
          ),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: DemoPinnedHeader(
                height: widget.compactHeader ? 120 : 121,
                child: Padding(
                  padding: widget.compactHeader
                      ? const EdgeInsets.fromLTRB(16, 0, 16, 20)
                      : const EdgeInsets.fromLTRB(18, 5, 18, 18),
                  child: Column(
                    children: [
                      DemoSearch(
                        hint: l.demoSearchAssets,
                        onChanged: (q) => setState(() => _query = q),
                        height: widget.compactHeader ? 42 : 44,
                        outlined: !widget.compactHeader,
                      ),
                      SizedBox(height: widget.compactHeader ? 10 : 18),
                      Row(
                        children: [
                          Expanded(
                            child: DemoSegments(
                              labels: [
                                l.demoAll,
                                l.demoImages,
                                l.demoVideos,
                                l.demoScripts,
                                l.demoAudio,
                              ],
                              selected: _filter,
                              onChanged: (v) => setState(() => _filter = v),
                              height: widget.compactHeader ? 34 : 36,
                              selectedFontWeight: widget.compactHeader
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              unselectedColor: widget.compactHeader
                                  ? AppColors.textTertiary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('demo-assets-layout-toggle'),
                            tooltip: _list ? l.demoAssets : l.demoOutputs,
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(36),
                              minimumSize: const Size.square(36),
                              maximumSize: const Size.square(36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _list = !_list),
                            icon: _list
                                ? const Icon(
                                    Icons.grid_view_outlined,
                                    size: 22,
                                    color: AppColors.textSecondary,
                                  )
                                : const DemoIcon(
                                    'list',
                                    size: 30,
                                    color: AppColors.textSecondary,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _query.isNotEmpty || _filter != 0
                        ? l.demoNoResults
                        : l.demoEmptyAssets,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  widget.compactHeader ? 16 : 18,
                  0,
                  widget.compactHeader ? 16 : 18,
                  MediaQuery.paddingOf(context).bottom + 20,
                ),
                sliver: _list
                    ? SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) => Padding(
                          key: ValueKey(items[i].id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            tileColor: demoSurface(context),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  items[i].kind == DemoAssetKind.audio ||
                                      items[i].kind == DemoAssetKind.script
                                  ? SizedBox.square(
                                      dimension: 54,
                                      child: DemoDocumentCover(
                                        kind: items[i].kind,
                                      ),
                                    )
                                  : DemoAssetImage(
                                      asset: items[i],
                                      width: 54,
                                      height: 54,
                                      cacheWidth: 162,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            title: Text(items[i].title),
                            subtitle: Text(
                              demoAssetMeta(l, items[i].kind, asset: items[i]),
                            ),
                            onTap: () => widget.onSelect != null
                                ? widget.onSelect!(items[i])
                                : openDemoAsset(
                                    context,
                                    items[i],
                                    repository: widget.repository,
                                  ),
                            trailing: widget.onSelect != null
                                ? const Icon(Icons.add_circle_outline)
                                : _assetMenu(
                                    context,
                                    items[i],
                                    widget.repository,
                                  ),
                          ),
                        ),
                      )
                    : SliverLayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 9.0;
                          final columns = constraints.crossAxisExtent >= 560
                              ? 3
                              : 2;
                          final cardWidth =
                              (constraints.crossAxisExtent -
                                  spacing * (columns - 1)) /
                              columns;
                          return SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                  mainAxisExtent: DemoAssetCard.heightForWidth(
                                    context,
                                    cardWidth,
                                  ),
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, i) => DemoAssetCard(
                              key: ValueKey(items[i].id),
                              asset: items[i],
                              onTap: () => widget.onSelect != null
                                  ? widget.onSelect!(items[i])
                                  : openDemoAsset(
                                      context,
                                      items[i],
                                      repository: widget.repository,
                                    ),
                              trailing: widget.onSelect != null
                                  ? const Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                    )
                                  : _assetMenu(
                                      context,
                                      items[i],
                                      widget.repository,
                                    ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }
}

Widget _assetMenu(
  BuildContext context,
  DemoAsset asset,
  DemoRepository repository,
) {
  final l = AppLocalizations.of(context)!;
  return AppMenuButton(
    tooltip: l.demoAssetDetails,
    size: 24,
    icon: const DemoIcon('more', size: 16, color: AppColors.textTertiary),
    entries: [
      AppMenuItem(
        label: l.demoAssetDetails,
        icon: const Icon(Icons.info_outline),
        onSelected: () => openDemoAsset(context, asset, repository: repository),
      ),
      AppMenuItem(
        label: l.renameProjectItem,
        icon: const Icon(Icons.edit_outlined),
        onSelected: () => demoEditText(
          context,
          title: l.demoRenameAsset,
          label: l.demoName,
          maxLength: 40,
          value: asset.title,
          onSave: (v) => repository.renameAsset(asset.id, v),
        ),
      ),
      AppMenuItem(
        label: l.delete,
        icon: const Icon(Icons.delete_outline),
        destructive: true,
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
            await demoPerform(context, () => repository.deleteAsset(asset.id));
          }
        },
      ),
    ],
  );
}

ShapeBorder _assetCardShape(BuildContext context) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(18),
  side: BorderSide(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: .12)
        : Colors.white.withValues(alpha: .82),
    width: .8,
  ),
);

String? _assetVideoDuration(DemoAsset asset) {
  if (asset.durationSeconds > 0) return _demoDuration(asset.durationSeconds);
  // The bundled fixture already used this known preview duration. Uploaded
  // assets without duration metadata must not inherit the sample value.
  return asset.isRemote ? null : '00:08';
}

class DemoAssetCard extends StatelessWidget {
  const DemoAssetCard({
    required this.asset,
    required this.onTap,
    this.trailing,
    super.key,
  });
  final DemoAsset asset;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Keeps square media and reserves a text-scaled footer for every consumer.
  static double heightForWidth(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final scaledFooter =
        8 + scaler.scale(16) * (22 / 16) + scaler.scale(13) * (20 / 13) + 4;
    return width + (scaledFooter < 64 ? 64 : scaledFooter);
  }

  @override
  Widget build(BuildContext context) {
    if (asset.kind == DemoAssetKind.audio ||
        asset.kind == DemoAssetKind.script) {
      return _DocumentAssetCard(asset: asset, onTap: onTap, trailing: trailing);
    }
    final duration = asset.kind == DemoAssetKind.video
        ? _assetVideoDuration(asset)
        : null;
    return Material(
      color: demoSurface(context),
      shape: _assetCardShape(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DemoAssetImage(
                        asset: asset,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                      ),
                      if (asset.kind == DemoAssetKind.video)
                        const Center(
                          child: DemoIcon(
                            'play',
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      if (duration != null)
                        Positioned(
                          right: 7,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: ShapeDecoration(
                              color: Colors.black.withValues(alpha: .3),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(
                  asset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 2, bottom: 4),
                child: Row(
                  children: [
                    DemoIcon(
                      asset.kind.name,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        demoAssetMeta(
                          AppLocalizations.of(context)!,
                          asset.kind,
                          asset: asset,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                          height: 20 / 13,
                        ),
                      ),
                    ),
                    if (trailing != null)
                      trailing!
                    else
                      const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentAssetCard extends StatelessWidget {
  const _DocumentAssetCard({
    required this.asset,
    required this.onTap,
    this.trailing,
  });
  final DemoAsset asset;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: demoSurface(context),
    shape: _assetCardShape(context),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: DemoDocumentCover(kind: asset.kind),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                asset.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 2, bottom: 4),
              child: Row(
                children: [
                  AppSvgIcon.asset(
                    asset.kind == DemoAssetKind.audio
                        ? 'demo_audio'
                        : 'demo_script_meta',
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      demoAssetMeta(
                        AppLocalizations.of(context)!,
                        asset.kind,
                        asset: asset,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 20 / 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void openDemoAsset(
  BuildContext context,
  DemoAsset asset, {
  DemoRepository? repository,
}) {
  if (asset.kind == DemoAssetKind.image && asset.isRemote) {
    AppImagePreview.show(
      context: context,
      image: demoAssetImageProviderForContext(context, asset),
      heroTag: 'asset-${asset.id}',
      label: asset.title,
    );
  } else if (asset.kind == DemoAssetKind.video && asset.isRemote) {
    AppMediaPreview.showGallery(
      context: context,
      items: [
        VideoPreviewItem(
          url: Uri.parse(asset.contentUrl),
          heroTag: 'asset-${asset.id}',
          label: asset.title,
          thumbnail: asset.posterUrl.isEmpty
              ? null
              : demoAssetImageProviderForContext(context, asset),
        ),
      ],
    );
  } else if (asset.kind == DemoAssetKind.script &&
      asset.isRemote &&
      repository != null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DemoScriptDetailPage(asset: asset, repository: repository),
      ),
    );
  } else if (asset.kind != DemoAssetKind.audio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SessionArtifactDetailPage(
          actions: [
            if (asset.kind == DemoAssetKind.script)
              IconButton(
                tooltip: AppLocalizations.of(context)!.copyAction,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: asset.body));
                  if (context.mounted) {
                    AppToast.success(
                      context,
                      AppLocalizations.of(context)!.demoUpdated,
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
              ),
          ],
          item: SessionArtifact(
            id: asset.id,
            type: switch (asset.kind) {
              DemoAssetKind.image => SessionArtifactType.image,
              DemoAssetKind.video => SessionArtifactType.video,
              _ => SessionArtifactType.script,
            },
            title: asset.title,
            summary: asset.body,
            metadata: demoAssetMeta(
              AppLocalizations.of(context)!,
              asset.kind,
              asset: asset,
            ),
            previewAsset: asset.cover,
            videoUrl: asset.kind == DemoAssetKind.video
                ? asset.isRemote
                      ? Uri.parse(asset.contentUrl)
                      : Uri(scheme: 'asset', path: asset.media)
                : null,
            textKind: asset.kind == DemoAssetKind.script ? 'script' : null,
          ),
        ),
      ),
    );
  } else {
    DemoSheet.show<void>(
      context: context,
      builder: (_) => DemoAudioDetail(
        asset: asset,
        readBytes: asset.isRemote && repository != null
            ? () => repository.readAssetBytes(asset)
            : null,
      ),
    );
  }
}
