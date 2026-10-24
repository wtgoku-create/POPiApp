import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/type/bot_avatar_type.dart';
import '../data/demo_fixtures.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart';

Future<String?> showDemoCreateSessionSheet({
  required BuildContext context,
  required DemoRepository repository,
  required String initialTitle,
  required DemoSessionKind kind,
}) => DemoSheet.show<String>(
  context: context,
  builder: (_) => _DemoCreateSessionSheet(
    repository: repository,
    initialTitle: initialTitle,
    kind: kind,
  ),
);

class _DemoCreateSessionSheet extends StatefulWidget {
  const _DemoCreateSessionSheet({
    required this.repository,
    required this.initialTitle,
    required this.kind,
  });

  final DemoRepository repository;
  final String initialTitle;
  final DemoSessionKind kind;

  @override
  State<_DemoCreateSessionSheet> createState() =>
      _DemoCreateSessionSheetState();
}

class _DemoCreateSessionSheetState extends State<_DemoCreateSessionSheet> {
  late final TextEditingController _title = TextEditingController(
    text: _limitTitle(widget.initialTitle),
  );
  late DemoAssistantProfile _selected = _initialAssistant();
  bool _busy = false;

  static String _limitTitle(String title) =>
      String.fromCharCodes(title.trim().runes.take(15));

  DemoAssistantProfile _initialAssistant() {
    final profiles = widget.repository.assistantProfiles;
    return profiles.firstWhere(
      (profile) => profile.memberId == 'popi' && profile.isBuiltIn,
      orElse: () => profiles.first,
    );
  }

  bool get _canCreate => _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _createAssistant() async {
    if (_busy) return;
    final draft = await _showAssistantEditor(context);
    if (draft != null && mounted) setState(() => _selected = draft);
  }

  Future<void> _create() async {
    if (_busy || !_canCreate) return;
    setState(() => _busy = true);
    String? id;
    final created = await demoPerform(context, () async {
      id = await widget.repository.createSession(
        _title.text.trim(),
        widget.kind,
        members: [_selected.memberId],
        assistant: _selected,
      );
    });
    if (!mounted) return;
    if (created) {
      Navigator.of(context).pop(id);
    } else {
      setState(() => _busy = false);
    }
  }

  String _name(AppLocalizations l, DemoAssistantProfile profile) =>
      profile.name.trim().isNotEmpty
      ? profile.name.trim()
      : profile.memberId == 'popi'
      ? l.demoPopiAssistant
      : demoMemberName(l, profile.memberId);

  String _description(AppLocalizations l, DemoAssistantProfile profile) =>
      profile.instructions.trim().isNotEmpty
      ? profile.instructions.trim()
      : demoMemberDescription(l, profile.memberId);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final storedProfiles = widget.repository.assistantProfiles;
    final profiles = storedProfiles.any((profile) => profile.id == _selected.id)
        ? storedProfiles
        : [_selected, ...storedProfiles];
    return PopScope(
      canPop: !_busy,
      child: DemoSheetBody(
        title: l.demoNew,
        footer: DemoPrimaryButton(
          key: const Key('demo-create-session-action'),
          label: l.demoCreateSessionAction,
          busy: _busy,
          onPressed: _canCreate ? _create : null,
        ),
        child: CustomScrollView(
          key: const Key('demo-create-session-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.demoSessionName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      style: const TextStyle(fontSize: 16),
                      key: const Key('demo-create-session-name'),
                      controller: _title,
                      enabled: !_busy,
                      maxLength: 15,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _create(),
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: demoTint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l.demoChooseAssistant,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.demoSingleAssistantNotice,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CreateAssistantTile(
                    enabled: !_busy,
                    onTap: _createAssistant,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            SliverList.separated(
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final selected = profile.id == _selected.id;
                final image = profile.avatarAsset.trim().isEmpty
                    ? DemoFixtures.memberImage(profile.memberId)
                    : profile.avatarAsset;
                return Semantics(
                  selected: selected,
                  button: true,
                  child: Material(
                    key: ValueKey(
                      'demo-create-member-${profile.isBuiltIn ? profile.memberId : profile.id}',
                    ),
                    color: selected ? demoTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _busy
                          ? null
                          : () => setState(() => _selected = profile),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            DemoAvatar(
                              image: image,
                              size: 60,
                              background: profile.avatarColor == null
                                  ? null
                                  : Color(profile.avatarColor!),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name(l, profile),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _description(l, profile),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            DemoSelectionMark(selected: selected),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

class _CreateAssistantTile extends StatelessWidget {
  const _CreateAssistantTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: demoTint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('demo-create-assistant'),
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const DecoratedBox(
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: CircleBorder(),
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.add, color: AppColors.brand),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.demoCreateAssistant,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DemoAssistantProfile?> _showAssistantEditor(BuildContext context) =>
    DemoSheet.show<DemoAssistantProfile>(
      context: context,
      builder: (_) => const _AssistantEditorSheet(),
    );

class _AssistantEditorSheet extends StatefulWidget {
  const _AssistantEditorSheet();

  @override
  State<_AssistantEditorSheet> createState() => _AssistantEditorSheetState();
}

class _AssistantEditorSheetState extends State<_AssistantEditorSheet> {
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

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      DemoAssistantProfile(
        id: 'draft:new:${DateTime.now().microsecondsSinceEpoch}',
        memberId: 'popi',
        name: name,
        instructions: _instructions.text.trim(),
        avatarAsset: _image,
        avatarColor: _color,
      ),
    );
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
    return DemoSheetBody(
      title: l.demoCreateAssistant,
      footer: DemoPrimaryButton(
        key: const Key('demo-create-assistant-confirm'),
        label: l.confirm,
        onPressed: _name.text.trim().isEmpty ? null : _confirm,
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
                  maxLength: 4000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _fieldDecoration(
                    hint: l.demoAssistantInstructionsHint,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(l.demoMyAppearance),
                    const Spacer(),
                    TextButton(
                      key: const Key('demo-assistant-random-avatar'),
                      onPressed: _randomizeAvatar,
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
                  onTap: () => setState(() => _image = character.stillAsset),
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
                          onTap: () => setState(() => _color = color),
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
