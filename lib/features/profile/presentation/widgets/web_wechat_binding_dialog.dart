import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/domain/web_social_login.dart';
import '../../../auth/presentation/web_social_login_panel.dart';
import '../../data/social_app_binding_repository.dart';
import '../../domain/social_app_binding.dart';

/// Serial polling is canceled when the dialog, QR scene or account changes.
class WebWechatBindingDialog extends ConsumerStatefulWidget {
  const WebWechatBindingDialog({
    required this.repository,
    required this.isCurrentUser,
    super.key,
  });

  final SocialAppBindingRepository repository;
  final bool Function() isCurrentUser;

  @override
  ConsumerState<WebWechatBindingDialog> createState() =>
      _WebWechatBindingDialogState();
}

class _WebWechatBindingDialogState
    extends ConsumerState<WebWechatBindingDialog> {
  WebSocialLoginChallenge? _challenge;
  CancelToken? _cancelToken;
  Timer? _pollTimer;
  Timer? _expiryTimer;
  bool _loading = true;
  bool _expired = false;
  bool _closing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(userProvider.select((user) => user?.id), (_, __) {
      _close();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  void _stop() {
    _generation++;
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    _cancelToken?.cancel();
  }

  bool _active(int generation) =>
      mounted && !_closing && generation == _generation;

  bool _current(int generation) {
    if (!_active(generation)) return false;
    if (widget.isCurrentUser()) return true;
    _close();
    return false;
  }

  void _close([SocialAppBinding? binding]) {
    if (!mounted || _closing) return;
    _closing = true;
    _stop();
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop(binding);
    } else {
      navigator.removeRoute(route, binding);
    }
  }

  Future<void> _load() async {
    _stop();
    final generation = _generation;
    final token = _cancelToken = CancelToken();
    setState(() {
      _loading = true;
      _expired = false;
      _challenge = null;
    });
    try {
      if (!_current(generation)) return;
      final challenge = await widget.repository.createWebWechatChallenge(
        cancelToken: token,
      );
      if (!_current(generation)) return;
      setState(() {
        _challenge = challenge;
        _loading = false;
      });
      _expiryTimer = Timer(challenge.expiresIn, () {
        if (!_current(generation)) return;
        _stop();
        setState(() => _expired = true);
      });
      unawaited(_poll(generation, token, challenge.state));
    } catch (error) {
      if (!mounted || !_current(generation) || token.isCancelled) return;
      setState(() => _loading = false);
      AppToast.error(
        context,
        AppLocalizations.of(context)!.socialBindingFailed,
      );
    }
  }

  Future<void> _poll(int generation, CancelToken token, String scene) async {
    if (!_current(generation)) return;
    try {
      final binding = await widget.repository.checkWebWechatBinding(
        scene,
        cancelToken: token,
      );
      if (!_current(generation)) return;
      if (binding != null) {
        _close(binding);
        return;
      }
      _pollTimer = Timer(const Duration(seconds: 2), () {
        unawaited(_poll(generation, token, scene));
      });
    } catch (error) {
      if (!mounted || !_current(generation) || token.isCancelled) return;
      _stop();
      AppToast.error(
        context,
        AppLocalizations.of(context)!.socialBindingFailed,
      );
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebSocialLoginPanel(
    key: const Key('web-wechat-binding-panel'),
    title: AppLocalizations.of(context)!.redemptionBindAction,
    douyin: false,
    loading: _loading,
    expired: _expired,
    qrUrl: _challenge?.url,
    onBack: _close,
    onRefresh: _load,
  );
}
