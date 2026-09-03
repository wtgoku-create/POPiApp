import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_toast.dart';

const userAgreementUrl =
    'https://tcnshqo5yu6i.feishu.cn/wiki/BmCNwr8o0ii19dkcTYAcaW9Jnhc';
const privacyPolicyUrl =
    'https://tcnshqo5yu6i.feishu.cn/wiki/Wu8mwLqOYi2nZjkur3rc18wFnbg';

typedef LegalUrlLauncher = Future<bool> Function(Uri uri);

class LegalDocumentLinks extends StatefulWidget {
  const LegalDocumentLinks({
    required this.text,
    required this.userAgreementLabel,
    required this.privacyPolicyLabel,
    required this.style,
    required this.linkStyle,
    required this.openFailedMessage,
    this.urlLauncher,
    super.key,
  });

  final String text;
  final String userAgreementLabel;
  final String privacyPolicyLabel;
  final TextStyle style;
  final TextStyle linkStyle;
  final String openFailedMessage;
  final LegalUrlLauncher? urlLauncher;

  @override
  State<LegalDocumentLinks> createState() => _LegalDocumentLinksState();
}

class _LegalDocumentLinksState extends State<LegalDocumentLinks> {
  late final TapGestureRecognizer _userAgreementRecognizer;
  late final TapGestureRecognizer _privacyPolicyRecognizer;

  @override
  void initState() {
    super.initState();
    _userAgreementRecognizer = TapGestureRecognizer()
      ..onTap = () => _open(userAgreementUrl);
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = () => _open(privacyPolicyUrl);
  }

  @override
  void dispose() {
    _userAgreementRecognizer.dispose();
    _privacyPolicyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userStart = widget.text.indexOf(widget.userAgreementLabel);
    final privacyStart = widget.text.indexOf(widget.privacyPolicyLabel);
    if (userStart < 0 || privacyStart < userStart) {
      return Text(widget.text, style: widget.style);
    }

    final userEnd = userStart + widget.userAgreementLabel.length;
    final privacyEnd = privacyStart + widget.privacyPolicyLabel.length;
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.text.substring(0, userStart)),
          TextSpan(
            text: widget.userAgreementLabel,
            style: widget.linkStyle,
            recognizer: _userAgreementRecognizer,
          ),
          TextSpan(text: widget.text.substring(userEnd, privacyStart)),
          TextSpan(
            text: widget.privacyPolicyLabel,
            style: widget.linkStyle,
            recognizer: _privacyPolicyRecognizer,
          ),
          TextSpan(text: widget.text.substring(privacyEnd)),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final launcher = widget.urlLauncher ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    try {
      if (await launcher(Uri.parse(url))) return;
    } catch (_) {
      // The same user-facing result applies when the platform cannot launch.
    }
    if (mounted) AppToast.error(context, widget.openFailedMessage);
  }
}
