import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// The phone verification step shared by WeChat and Douyin authorization.
class PhoneBindingPage extends StatelessWidget {
  const PhoneBindingPage({
    super.key,
    required this.douyin,
    required this.busy,
    required this.onBack,
    required this.form,
    required this.agreement,
  });

  final bool douyin;
  final bool busy;
  final VoidCallback onBack;
  final Widget form;
  final Widget agreement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) onBack();
      },
      child: Scaffold(
        key: const Key('phone-binding-page'),
        backgroundColor: theme.colorScheme.surface,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(l10n.bindPhone),
          centerTitle: true,
          leading: IconButton(
            key: const Key('phone-binding-back-button'),
            tooltip: l10n.backToPreviousPage,
            onPressed: busy ? null : onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        douyin
                            ? 'assets/images/login_douyin.png'
                            : 'assets/images/login_wechat.png',
                        width: 48,
                        height: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        douyin
                            ? l10n.douyinPhoneBindingRequired
                            : l10n.wechatPhoneBindingRequired,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      form,
                      const SizedBox(height: 24),
                      agreement,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
