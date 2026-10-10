import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../data/redemption_repository.dart';
import '../../domain/redemption.dart';
import 'redemption_qr_image.dart';

class WechatBindingDialog extends StatefulWidget {
  const WechatBindingDialog({required this.repository, super.key});

  final RedemptionRepository repository;

  @override
  State<WechatBindingDialog> createState() => _WechatBindingDialogState();
}

class _WechatBindingDialogState extends State<WechatBindingDialog>
    with WidgetsBindingObserver {
  WechatBindingQrCode? _qr;
  Timer? _timer;
  bool _loading = false;
  bool _checking = false;
  bool _failed = false;
  bool _checkFailed = false;
  int _request = 0;

  bool get _expired => _qr != null && !DateTime.now().isBefore(_qr!.expiresAt);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _load() async {
    if (_loading || _checking) return;
    final request = ++_request;
    _timer?.cancel();
    setState(() {
      _loading = true;
      _failed = false;
      _checkFailed = false;
      _qr = null;
    });
    try {
      final qr = await widget.repository.fetchBindingQrCode();
      if (!mounted || request != _request) return;
      setState(() => _qr = qr);
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
          unawaited(_check());
        }
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _check() async {
    if (_qr == null || _checking) return;
    if (_expired) {
      _timer?.cancel();
      if (mounted) setState(() {});
      return;
    }
    final request = _request;
    setState(() {
      _checking = true;
      _checkFailed = false;
    });
    try {
      final bound = await widget.repository.checkBinding(_qr!.sceneCode);
      if (!mounted || request != _request) return;
      if (bound) {
        _timer?.cancel();
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted && request == _request) setState(() => _checkFailed = true);
    } finally {
      if (mounted && request == _request) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.redemptionBindAction,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(l10n.redemptionBindDescription, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox.square(
              dimension: 240,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed || _expired) ...[
            Text(
              _expired ? l10n.redemptionQrExpired : l10n.redemptionQrFailed,
              textAlign: TextAlign.center,
            ),
            TextButton.icon(
              onPressed: _checking ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ] else if (_qr != null) ...[
            RedemptionQrImage(url: _qr!.url),
            const SizedBox(height: 16),
            Text(
              _checkFailed
                  ? l10n.redemptionLoadFailed
                  : l10n.redemptionBindingWaiting,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _qr == null || _expired || _checking
                      ? null
                      : _check,
                  child: Text(
                    l10n.redemptionBindingCheck,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
