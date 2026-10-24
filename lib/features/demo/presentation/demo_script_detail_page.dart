import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../session/domain/session_artifact.dart';
import '../../session/presentation/widgets/session_artifacts_sheet.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart';

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
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return SessionArtifactDetailPage(
      item: SessionArtifact(
        id: widget.asset.id,
        type: SessionArtifactType.script,
        title: widget.asset.title,
        summary: _body,
        metadata: l.demoScripts,
        textKind: 'script',
      ),
      actions: [
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
}
