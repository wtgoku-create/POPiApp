import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/privacy_consent_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/legal_document_links.dart';
import '../../h5/presentation/h5_page.dart';

/// A local-only entry point, separate from the business router and its services.
class PrivacyConsentPage extends StatefulWidget {
  const PrivacyConsentPage({super.key});

  @override
  State<PrivacyConsentPage> createState() => _PrivacyConsentPageState();
}

class _PrivacyConsentPageState extends State<PrivacyConsentPage> {
  bool _noticeOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showNotice();
    });
  }

  Future<void> _showNotice() async {
    if (_noticeOpen) return;
    setState(() => _noticeOpen = true);
    await AppDialog.show<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PrivacyConsentDialog(),
    );
    if (!mounted) return;
    setState(() => _noticeOpen = false);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'POPi',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  if (!_noticeOpen) ...[
                    const SizedBox(height: 24),
                    Text(
                      l10n.privacyConsentRequired,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _showNotice,
                      child: Text(l10n.privacyConsentReview),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyConsentDialog extends ConsumerStatefulWidget {
  const _PrivacyConsentDialog();

  @override
  ConsumerState<_PrivacyConsentDialog> createState() =>
      _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends ConsumerState<_PrivacyConsentDialog> {
  bool _saving = false;

  Future<void> _accept() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(privacyConsentProvider.notifier).accept();
      // StarterApp replaces this entire entry point once persistence succeeds.
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(
          context,
          AppLocalizations.of(context)!.privacyConsentSaveFailed,
        );
      }
    }
  }

  Future<bool> _openDocument(Uri uri) async {
    final l10n = AppLocalizations.of(context)!;
    await H5Page.open(
      context,
      title: uri == Uri.parse(userAgreementUrl)
          ? l10n.userAgreement
          : l10n.privacyPolicy,
      url: uri,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AppDialog(
        key: const Key('privacy-consent-dialog'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.privacyConsentTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 25),
            IgnorePointer(
              ignoring: _saving,
              child: LegalDocumentLinks(
                text: l10n.privacyConsentMessage,
                userAgreementLabel: l10n.userAgreement,
                privacyPolicyLabel: l10n.privacyPolicy,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 16,
                  height: 1.5,
                ),
                linkStyle: TextStyle(color: colors.primary),
                openFailedMessage: l10n.networkRequestFailed,
                urlLauncher: _openDocument,
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 50),
                    child: TextButton(
                      key: const Key('privacy-consent-decline'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        backgroundColor: colors.onSurface.withValues(
                          alpha: .05,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: Text(
                        l10n.privacyConsentDecline,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 50),
                    child: FilledButton(
                      key: const Key('privacy-consent-accept'),
                      onPressed: _saving ? null : _accept,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _saving ? 0 : 1,
                            child: Text(
                              l10n.privacyConsentAccept,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (_saving)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
