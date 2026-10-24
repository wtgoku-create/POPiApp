import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/type/bot_avatar_type.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart';

/// Creates the Popi and its first conversation in one confirmation.
Future<String?> showDemoCreateSessionSheet({
  required BuildContext context,
  required DemoRepository repository,
  required DemoSessionKind kind,
}) => DemoSheet.show<String>(
  context: context,
  enableDrag: false,
  builder: (_) => _DemoCreateSessionSheet(repository: repository, kind: kind),
);

class _DemoCreateSessionSheet extends StatefulWidget {
  const _DemoCreateSessionSheet({required this.repository, required this.kind});

  final DemoRepository repository;
  final DemoSessionKind kind;

  @override
  State<_DemoCreateSessionSheet> createState() =>
      _DemoCreateSessionSheetState();
}

class _DemoCreateSessionSheetState extends State<_DemoCreateSessionSheet> {
  static const _colors = [
    0xFFFFFFFF,
    0xFFE4DCFE,
    0xFFD6E8FF,
    0xFFCFF4F6,
    0xFFD6F5E1,
    0xFFFCDCCE,
    0xFFFFDFEF,
    0xFFDCE4FB,
  ];

  final _name = TextEditingController();
  final _instructions = TextEditingController();
  String _image = BotAvatarCharacter.tiger.stillAsset;
  int _color = 0xFFFFDFEF;
  final _draftId = 'draft:new:${DateTime.now().microsecondsSinceEpoch}';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _name.text.trim();
    if (_busy || name.isEmpty) return;
    setState(() => _busy = true);
    String? sessionId;
    final created = await demoPerform(context, () async {
      sessionId = await widget.repository.createSession(
        name,
        widget.kind,
        members: const ['popi'],
        assistant: DemoAssistantProfile(
          id: _draftId,
          memberId: 'popi',
          name: name,
          instructions: _instructions.text.trim(),
          avatarAsset: _image,
          avatarColor: _color,
        ),
      );
    });
    if (!mounted) return;
    if (created) {
      Navigator.of(context).pop(sessionId);
    } else {
      setState(() => _busy = false);
    }
  }

  void _randomizeAvatar() {
    final current = BotAvatarCharacter.values.indexWhere(
      (character) => character.stillAsset == _image,
    );
    setState(() {
      _image = BotAvatarCharacter
          .values[(current + 1) % BotAvatarCharacter.values.length]
          .stillAsset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: DemoSheetBody(
        title: l.demoCreateAssistant,
        footer: DemoPrimaryButton(
          key: const Key('demo-create-assistant-confirm'),
          label: l.confirm,
          busy: _busy,
          onPressed: _busy || _name.text.trim().isEmpty ? null : _confirm,
        ),
        child: CustomScrollView(
          key: const Key('demo-create-assistant-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: DemoAvatar(
                      image: _image,
                      size: 80,
                      background: Color(_color),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.demoAssistantName),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('demo-assistant-name'),
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 10,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      suffix: '${_name.text.characters.length}/10',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.demoAssistantInstructions),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('demo-assistant-instructions'),
                    controller: _instructions,
                    enabled: !_busy,
                    maxLength: 4000,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _fieldDecoration(
                      hint: l.demoAssistantInstructionsHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(l.demoMyAppearance),
                      TextButton(
                        key: const Key('demo-assistant-random-avatar'),
                        onPressed: _busy ? null : _randomizeAvatar,
                        child: Text(
                          l.demoRandomAppearance,
                          style: const TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 60,
              ),
              itemCount: BotAvatarCharacter.values.length,
              itemBuilder: (context, index) {
                final character = BotAvatarCharacter.values[index];
                final selected = _image == character.stillAsset;
                return Semantics(
                  key: ValueKey('demo-assistant-avatar-${character.name}'),
                  label: l.demoAvatarNumber(index + 1),
                  selected: selected,
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _busy
                        ? null
                        : () => setState(() => _image = character.stillAsset),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFE9E3F8)
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      child: Image.asset(
                        character.stillAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  Text(l.demoBackgroundColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final color in _colors)
                        Semantics(
                          label: l.demoBackgroundColor,
                          selected: _color == color,
                          button: true,
                          child: InkWell(
                            key: ValueKey('demo-assistant-color-$color'),
                            customBorder: const CircleBorder(),
                            onTap: _busy
                                ? null
                                : () => setState(() => _color = color),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Color(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _color == color
                                      ? AppColors.brand
                                      : const Color(0xFFE5E5E5),
                                  width: _color == color ? 2 : 1,
                                ),
                              ),
                              child: _color == color
                                  ? const Center(
                                      child: DemoIcon(
                                        'check',
                                        size: 18,
                                        color: AppColors.brand,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: demoTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        suffixIcon: suffix == null
            ? null
            : Center(
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(suffix),
                ),
              ),
      );
}
