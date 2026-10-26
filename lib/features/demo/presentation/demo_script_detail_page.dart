import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../session/domain/session_artifact.dart';
import '../../session/presentation/widgets/session_artifacts_sheet.dart';
import '../data/demo_repository.dart';
import '../data/demo_media_exporter.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart';
import '../../../shared/widgets/app_skeleton.dart';

/// Loads uploaded text only when its detail page is opened.
class DemoScriptDetailPage extends StatefulWidget {
  const DemoScriptDetailPage({
    required this.asset,
    required this.repository,
    super.key,
  });
  final DemoAsset asset;
  final DemoRepository repository;

  @override
  State<DemoScriptDetailPage> createState() => _DemoScriptDetailPageState();
}

class _DemoScriptDetailPageState extends State<DemoScriptDetailPage> {
  String _body = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final body = await widget.repository.readAssetText(widget.asset);
      if (mounted) setState(() => _body = body);
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.demoAssetLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return DemoScaffold(
        title: Text(widget.asset.title),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AppSkeleton(
            label: l.demoDocumentParsing,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSkeletonBox(height: 22, width: 180, radius: 8),
                SizedBox(height: 18),
                AppSkeletonBox(height: 18, radius: 8),
                SizedBox(height: 10),
                AppSkeletonBox(height: 18, radius: 8),
                SizedBox(height: 10),
                AppSkeletonBox(height: 220, radius: 18),
              ],
            ),
          ),
        ),
      );
    }
    final document = widget.asset.document;
    final metadata = <String>[
      if (document?.format.trim().isNotEmpty == true)
        document!.format.trim().toUpperCase()
      else
        l.demoScripts,
      if (document?.pageCount case final count?) l.demoDocumentPages(count),
      if (document?.slideCount case final count?) l.demoDocumentSlides(count),
      if (document?.ocrUsed == true) l.demoDocumentOcrUsed,
      if (document?.pageCountEstimated == true)
        l.demoDocumentPageCountEstimated,
      if (document?.truncated == true) l.demoDocumentTruncated,
      if (widget.asset.isDocument) l.demoDocumentOriginalAvailable,
    ].join(' · ');
    return SessionArtifactDetailPage(
      item: SessionArtifact(
        id: widget.asset.id,
        type: SessionArtifactType.script,
        title: widget.asset.title,
        summary: _body.isEmpty && widget.asset.isDocument
            ? l.demoDocumentTextEmpty
            : _body,
        metadata: metadata,
        textKind: widget.asset.isDocument ? null : 'script',
      ),
      actions: [
        if (widget.asset.isDocument)
          IconButton(
            key: const Key('demo-document-download-original'),
            tooltip: l.download,
            onPressed: _saving ? null : _saveOriginal,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
        IconButton(
          tooltip: l.copyAction,
          onPressed: _body.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: _body));
                  if (context.mounted) AppToast.success(context, l.demoUpdated);
                },
          icon: const Icon(Icons.copy_outlined),
        ),
      ],
    );
  }

  Future<void> _saveOriginal() async {
    final box = context.findRenderObject()! as RenderBox;
    setState(() => _saving = true);
    try {
      final saved = await DemoMediaExporter.save(
        widget.asset,
        box.localToGlobal(Offset.zero) & box.size,
        readBytes: () => widget.repository.readAssetBytes(widget.asset),
      );
      if (mounted && saved) {
        AppToast.success(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaved,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
