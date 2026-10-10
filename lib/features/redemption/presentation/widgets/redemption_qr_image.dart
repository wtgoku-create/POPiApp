import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

class RedemptionQrImage extends StatefulWidget {
  const RedemptionQrImage({required this.url, super.key});
  final String url;

  @override
  State<RedemptionQrImage> createState() => _RedemptionQrImageState();
}

class _RedemptionQrImageState extends State<RedemptionQrImage> {
  int _attempt = 0;

  Future<void> _retry() async {
    await NetworkImage(widget.url).evict();
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: ColoredBox(
      color: Colors.white,
      child: Image.network(
        widget.url,
        key: ValueKey('${widget.url}-$_attempt'),
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, _, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.redemptionQrFailed,
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
