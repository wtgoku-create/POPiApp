import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../session/domain/session_artifact.dart';
import '../../session/presentation/widgets/session_artifacts_sheet.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/data/v2_fixtures.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';
import 'widgets/v2_document_cover.dart';
import 'v2_audio_detail.dart';

String v2AssetMeta(AppLocalizations l, V2AssetKind kind) => switch (kind) {
  V2AssetKind.image => l.demoImageMeta,
  V2AssetKind.video => l.demoVideoMeta,
  V2AssetKind.script => l.demoScriptMeta,
  V2AssetKind.audio => l.demoAudioMeta,
};
IconData v2AssetIcon(V2AssetKind kind) => switch (kind) {
  V2AssetKind.image => Icons.image_outlined,
  V2AssetKind.video => Icons.videocam_outlined,
  V2AssetKind.script => Icons.description_outlined,
  V2AssetKind.audio => Icons.music_note_outlined,
};

Future<void> showV2Import(BuildContext context, V2Repository repository) =>
    V2Sheet.show<void>(
      context: context,
      builder: (_) => _ImportSheet(repository: repository),
    );

class _ImportSheet extends StatefulWidget {
  const _ImportSheet({required this.repository});
  final V2Repository repository;
  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _selected = V2AssetKind.values.toList();
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final examples = {
      for (final kind in V2AssetKind.values)
        kind:
            widget.repository.assets.where((a) => a.kind == kind).firstOrNull ??
            V2Fixtures.assets().firstWhere((a) => a.kind == kind),
    };
    return V2SheetBody(
      title: l.demoUpload,
      footer: V2PrimaryButton(
        label: l.demoUploadLibrary,
        busy: _busy,
        onPressed: _selected.isEmpty
            ? null
            : () async {
                setState(() => _busy = true);
                final ok = await v2Perform(context, () async {
                  for (final kind in List.of(_selected)) {
                    await widget.repository.importSample(kind);
                    if (mounted) setState(() => _selected.remove(kind));
                  }
                });
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
            color: v2Tint,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _busy
                  ? null
                  : () => setState(() {
                      for (final kind in V2AssetKind.values) {
                        if (!_selected.contains(kind)) _selected.add(kind);
                      }
                    }),
              child: SizedBox(
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const V2Icon('upload', size: 32, color: AppColors.brand),
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
                  key: ValueKey(kind),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: v2Surface(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child:
                            kind == V2AssetKind.script ||
                                kind == V2AssetKind.audio
                            ? Container(
                                width: 50,
                                height: 50,
                                color: v2Tint,
                                child: Center(
                                  child: V2Icon(
                                    kind.name,
                                    size: 24,
                                    color: AppColors.brand,
                                  ),
                                ),
                              )
                            : Image.asset(
                                asset.cover,
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
                                    V2AssetKind.image => '.png',
                                    V2AssetKind.video => '.mp4',
                                    V2AssetKind.script => '.md',
                                    V2AssetKind.audio => '.mp4',
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
                              v2AssetMeta(l, kind),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: l.delete,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _selected.remove(kind)),
                        icon: const V2Icon(
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
    );
  }
}

class V2AssetsView extends StatefulWidget {
  const V2AssetsView({
    required this.repository,
    this.sessionId,
    this.onSelect,
    this.compactHeader = false,
    super.key,
  });
  final V2Repository repository;
  final String? sessionId;
  final ValueChanged<V2Asset>? onSelect;
  final bool compactHeader;
  @override
  State<V2AssetsView> createState() => _V2AssetsViewState();
}

class _V2AssetsViewState extends State<V2AssetsView> {
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
              delegate: V2PinnedHeader(
                height: widget.compactHeader ? 120 : 140,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    widget.compactHeader ? 0 : 10,
                    20,
                    20,
                  ),
                  child: Column(
                    children: [
                      V2Search(
                        hint: l.demoSearchAssets,
                        onChanged: (q) => setState(() => _query = q),
                      ),
                      SizedBox(height: widget.compactHeader ? 10 : 20),
                      Row(
                        children: [
                          Expanded(
                            child: V2Segments(
                              labels: [
                                l.demoAll,
                                l.demoImages,
                                l.demoVideos,
                                l.demoScripts,
                                l.demoAudio,
                              ],
                              selected: _filter,
                              onChanged: (v) => setState(() => _filter = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
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
                                ? const Icon(Icons.grid_view_outlined, size: 22)
                                : const V2Icon('list', size: 30),
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
                  20,
                  0,
                  20,
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
                            tileColor: v2Surface(context),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  items[i].kind == V2AssetKind.audio ||
                                      items[i].kind == V2AssetKind.script
                                  ? SizedBox.square(
                                      dimension: 54,
                                      child: V2DocumentCover(
                                        kind: items[i].kind,
                                      ),
                                    )
                                  : Image.asset(
                                      items[i].cover,
                                      width: 54,
                                      height: 54,
                                      cacheWidth: 162,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            title: Text(items[i].title),
                            subtitle: Text(v2AssetMeta(l, items[i].kind)),
                            onTap: () => widget.onSelect != null
                                ? widget.onSelect!(items[i])
                                : openV2Asset(context, items[i]),
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
                        builder: (context, constraints) => SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    constraints.crossAxisExtent >= 560 ? 3 : 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent:
                                    (constraints.crossAxisExtent -
                                            (constraints.crossAxisExtent >= 560
                                                ? 20
                                                : 10)) /
                                        (constraints.crossAxisExtent >= 560
                                            ? 3
                                            : 2) +
                                    72,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, i) => V2AssetCard(
                            key: ValueKey(items[i].id),
                            asset: items[i],
                            onTap: () => widget.onSelect != null
                                ? widget.onSelect!(items[i])
                                : openV2Asset(context, items[i]),
                            trailing: widget.onSelect != null
                                ? const Icon(Icons.add_circle_outline, size: 20)
                                : _assetMenu(
                                    context,
                                    items[i],
                                    widget.repository,
                                  ),
                          ),
                        ),
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
  V2Asset asset,
  V2Repository repository,
) {
  final l = AppLocalizations.of(context)!;
  return AppMenuButton(
    tooltip: l.demoAssetDetails,
    size: asset.kind == V2AssetKind.audio || asset.kind == V2AssetKind.script
        ? 24
        : 32,
    icon: V2Icon(
      'more',
      size: asset.kind == V2AssetKind.audio || asset.kind == V2AssetKind.script
          ? 16
          : 18,
    ),
    entries: [
      AppMenuItem(
        label: l.demoAssetDetails,
        icon: const Icon(Icons.info_outline),
        onSelected: () => openV2Asset(context, asset),
      ),
      AppMenuItem(
        label: l.renameProjectItem,
        icon: const Icon(Icons.edit_outlined),
        onSelected: () => v2EditText(
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
            await v2Perform(context, () => repository.deleteAsset(asset.id));
          }
        },
      ),
    ],
  );
}

class V2AssetCard extends StatelessWidget {
  const V2AssetCard({
    required this.asset,
    required this.onTap,
    this.trailing,
    super.key,
  });
  final V2Asset asset;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) =>
      asset.kind == V2AssetKind.audio || asset.kind == V2AssetKind.script
      ? _DocumentAssetCard(asset: asset, onTap: onTap, trailing: trailing)
      : Material(
          color: v2Surface(context),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            asset.cover,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                          ),
                          if (asset.kind == V2AssetKind.video)
                            const Center(
                              child: V2Icon(
                                'play',
                                size: 40,
                                color: Colors.white,
                              ),
                            )
                          else if (asset.kind != V2AssetKind.image)
                            Center(
                              child: CircleAvatar(
                                backgroundColor: Colors.black38,
                                child: Icon(
                                  asset.kind == V2AssetKind.video
                                      ? Icons.play_arrow_rounded
                                      : v2AssetIcon(asset.kind),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (asset.kind == V2AssetKind.video)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: const ShapeDecoration(
                                  color: Colors.black38,
                                  shape: StadiumBorder(),
                                ),
                                child: const Text(
                                  '00:08',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                    child: Text(
                      asset.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 25 / 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 15,
                      right: 5,
                      bottom: 5,
                    ),
                    child: Row(
                      children: [
                        V2Icon(
                          asset.kind.name,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            v2AssetMeta(
                              AppLocalizations.of(context)!,
                              asset.kind,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (trailing != null)
                          trailing!
                        else
                          const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
}

class _DocumentAssetCard extends StatelessWidget {
  const _DocumentAssetCard({
    required this.asset,
    required this.onTap,
    this.trailing,
  });
  final V2Asset asset;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: v2Surface(context),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: V2DocumentCover(kind: asset.kind),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                asset.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 25 / 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 11),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    AppSvgIcon.asset(
                      asset.kind == V2AssetKind.audio
                          ? 'demo_audio'
                          : 'demo_script_meta',
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        v2AssetMeta(AppLocalizations.of(context)!, asset.kind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void openV2Asset(BuildContext context, V2Asset asset) {
  if (asset.kind != V2AssetKind.audio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SessionArtifactDetailPage(
          actions: [
            if (asset.kind == V2AssetKind.script)
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
              V2AssetKind.image => SessionArtifactType.image,
              V2AssetKind.video => SessionArtifactType.video,
              _ => SessionArtifactType.script,
            },
            title: asset.title,
            summary: asset.body,
            metadata: v2AssetMeta(AppLocalizations.of(context)!, asset.kind),
            previewAsset: asset.cover,
            videoUrl: asset.kind == V2AssetKind.video
                ? Uri(scheme: 'asset', path: asset.media)
                : null,
            textKind: asset.kind == V2AssetKind.script ? 'script' : null,
          ),
        ),
      ),
    );
  } else {
    V2Sheet.show<void>(
      context: context,
      builder: (_) => V2AudioDetail(asset: asset),
    );
  }
}
