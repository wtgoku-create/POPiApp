import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

/// Collects a custom topic prompt before submitting the creation command.
class HomeTopicInputSheet extends StatefulWidget {
  const HomeTopicInputSheet({super.key});

  @override
  State<HomeTopicInputSheet> createState() => _HomeTopicInputSheetState();
}

class _HomeTopicInputSheetState extends State<HomeTopicInputSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: RoleGuideSheet(
        title: l10n.roleCustomTopic,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            TextField(
              key: const Key('home-topic-input'),
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              maxLength: 16000,
              decoration: InputDecoration(hintText: l10n.roleCustomTopicHint),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        footer: RoleGuideAction(
          key: const Key('home-topic-submit'),
          label: l10n.roleGenerateTopic,
          showArrow: false,
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ),
    );
  }
}
