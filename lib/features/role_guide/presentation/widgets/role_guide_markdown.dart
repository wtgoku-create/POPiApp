import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Consistent Markdown typography for story and generation content.
class RoleGuideMarkdown extends StatelessWidget {
  const RoleGuideMarkdown({
    required this.text,
    this.color,
    this.softLineBreak = false,
    super.key,
  });

  final String text;
  final Color? color;
  final bool softLineBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: color ?? theme.colorScheme.onSurface,
    );
    return MarkdownBody(
      data: text,
      selectable: true,
      softLineBreak: softLineBreak,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: bodyStyle,
        listBullet: bodyStyle,
        blockquote: bodyStyle,
        blockSpacing: 12,
        h1: bodyStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
        h2: bodyStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
        h3: bodyStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      onTapLink: (_, href, __) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri != null && ['https', 'http'].contains(uri.scheme)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
