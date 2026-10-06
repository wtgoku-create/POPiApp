import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

class AssetPreviewPage extends StatelessWidget {
  const AssetPreviewPage({
    super.key,
    required this.asset,
    this.isVideo = false,
  });

  final String asset;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('asset-preview-page'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          key: const Key('asset-preview-back'),
          tooltip: l10n.backToPreviousPage,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(isVideo ? l10n.videoCoverPreview : l10n.assetPreview),
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: InteractiveViewer(
            key: const Key('asset-preview-image'),
            minScale: 1,
            maxScale: 4,
            child: Center(child: Image.asset(asset, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }
}
