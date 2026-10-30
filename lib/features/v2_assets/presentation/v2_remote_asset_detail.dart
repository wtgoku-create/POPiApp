import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_video_player.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_shared/presentation/widgets/v2_media_image.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';
import '../data/v2_media_exporter.dart';

/// Previews server media and exports original bytes through the owned repository.
class V2RemoteAssetDetail extends StatefulWidget {
  const V2RemoteAssetDetail({
    required this.asset,
    required this.repository,
    super.key,
  });
  final V2Asset asset;
  final V2Repository repository;
  @override
  State<V2RemoteAssetDetail> createState() => _V2RemoteAssetDetailState();
}

class _V2RemoteAssetDetailState extends State<V2RemoteAssetDetail> {
  String? _text;
  bool _loading = false;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    if (widget.asset.kind == V2AssetKind.script) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadText());
    }
  }

  Future<void> _loadText() async {
    await v2Perform(context, () async {
      final text = await widget.repository.readAssetText(widget.asset);
      if (mounted) setState(() => _text = text);
    });
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _saving = true);
    await v2Perform(context, () async {
      final bytes = await widget.repository.readAssetBytes(widget.asset);
      if (!mounted) return;
      final saved = await V2MediaExporter.save(
        widget.asset,
        origin,
        bytes: bytes,
      );
      if (mounted && saved) {
        AppToast.success(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaved,
        );
      }
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final l = AppLocalizations.of(context)!;
    return V2Scaffold(
      title: Text(a.title),
      actions: [
        if (_text != null)
          IconButton(
            tooltip: l.copyAction,
            onPressed: () => Clipboard.setData(ClipboardData(text: _text!)),
            icon: const Icon(Icons.copy_outlined),
          ),
        IconButton(
          tooltip: l.download,
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
        ),
      ],
      child: switch (a.kind) {
        V2AssetKind.image => Center(
          child: GestureDetector(
            onTap: () => AppImagePreview.show(
              context: context,
              image: v2ImageProvider(a.contentUrl, headers: a.headers),
              label: a.title,
              heroTag: 'v2-asset-${a.id}',
            ),
            child: V2MediaImage(
              a.contentUrl,
              headers: a.headers,
              fit: BoxFit.contain,
            ),
          ),
        ),
        V2AssetKind.video => Center(
          child: AppVideoPlayer(
            url: Uri.parse(a.media),
            httpHeaders: a.headers,
          ),
        ),
        V2AssetKind.script =>
          _loading
              ? AppSkeletonList(label: l.loadingAssets)
              : Markdown(data: _text ?? ''),
        V2AssetKind.audio => const SizedBox.shrink(),
      },
    );
  }
}
