import 'package:flutter/material.dart';

import '../../../core/utils/app_url.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_skeleton.dart';

/// A fixed-size browser authorization surface shared by QR and OAuth login.
class WebSocialLoginPanel extends StatelessWidget {
  const WebSocialLoginPanel({
    super.key,
    required this.douyin,
    required this.loading,
    required this.expired,
    required this.qrUrl,
    required this.onBack,
    required this.onRefresh,
  });

  final bool douyin;
  final bool loading;
  final bool expired;
  final String? qrUrl;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        key: const Key('web-social-login-panel'),
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.backToPreviousPage,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          title: Text(douyin ? l10n.douyinLogin : l10n.wechatScanLogin),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 240,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : expired
                      ? const Icon(Icons.timer_off_outlined, size: 64)
                      : douyin
                      ? Center(
                          child: Image.asset(
                            'assets/images/login_douyin.png',
                            width: 64,
                            height: 64,
                          ),
                        )
                      : qrUrl == null
                      ? const Icon(Icons.qr_code_2, size: 120)
                      : Image.network(
                          AppUrl.resolve(qrUrl!),
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          key: ValueKey(qrUrl),
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const AppSkeletonBox(width: 240, height: 240),
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, size: 64),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  expired
                      ? l10n.socialLoginExpired
                      : douyin
                      ? l10n.douyinWebAuthorizing
                      : l10n.wechatScanLogin,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                IconButton(
                  key: const Key('web-social-login-refresh'),
                  tooltip: l10n.refreshSocialLogin,
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
