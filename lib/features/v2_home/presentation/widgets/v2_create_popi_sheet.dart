import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/type/bot_avatar_type.dart';
import '../../../v2_shared/data/v2_repository.dart';
import '../../../v2_shared/domain/v2_models.dart';
import '../../../v2_shared/presentation/widgets/v2_widgets.dart';

/// Collects and saves the assistant configuration before opening its chat.
class V2CreatePopiSheet extends StatefulWidget {
  const V2CreatePopiSheet({required this.repository, super.key});

  final V2Repository repository;

  @override
  State<V2CreatePopiSheet> createState() => _V2CreatePopiSheetState();
}

class _V2CreatePopiSheetState extends State<V2CreatePopiSheet> {
  static const _colors = [
    0xFFFFFFFF,
    0xFFE4DCFE,
    0xFFD6E7FF,
    0xFFCFF4F6,
    0xFFD6F5E1,
    0xFFFCDCCE,
    0xFFFFDFEF,
    0xFFDCE4FB,
  ];
  final _name = TextEditingController(text: 'POPi');
  final _instructions = TextEditingController();
  final _random = math.Random();
  BotAvatarCharacter _avatar = BotAvatarCharacter.horse;
  int _color = 0xFFFCDCCE;
  bool _busy = false;
  String _avatarAsset(BotAvatarCharacter avatar) =>
      'assets/images/popi_avatar_${avatar.name}.png';

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || _name.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    String? id;
    final ok = await v2Perform(context, () async {
      id = await widget.repository.createSession(
        _name.text.trim(),
        V2SessionKind.conversation,
        memberNames: {'popi': _name.text.trim()},
        memberInstructions: {'popi': _instructions.text.trim()},
        memberAvatars: {'popi': _avatarAsset(_avatar)},
        memberColors: {'popi': _color},
      );
    });
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(id);
    } else {
      setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    hintText: label,
    filled: true,
    fillColor: v2Tint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: V2SheetBody(
        title: l.v2CreatePopi,
        footer: V2PrimaryButton(
          key: const Key('v2-create-popi-confirm'),
          label: l.confirm,
          busy: _busy,
          onPressed: _name.text.trim().isEmpty ? null : _create,
        ),
        child: CustomScrollView(
          key: const Key('v2-create-popi-form'),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: V2Avatar(
                      key: const Key('v2-create-popi-preview'),
                      image: _avatarAsset(_avatar),
                      size: 100,
                      background: Color(_color),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    l.demoMyName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('v2-create-popi-name'),
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 10,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 18, height: 1.2),
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(l.demoMyName).copyWith(
                      counterText: '',
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '${_name.text.characters.length}/10',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.v2PopiPersonality,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('v2-create-popi-instructions'),
                    controller: _instructions,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    decoration: _decoration(l.v2PopiPersonalityHint).copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.demoMyAppearance,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                final others = BotAvatarCharacter.values
                                    .where((value) => value != _avatar)
                                    .toList();
                                _avatar =
                                    others[_random.nextInt(others.length)];
                              }),
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
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: BotAvatarCharacter.values.length,
              itemBuilder: (context, index) {
                final avatar = BotAvatarCharacter.values[index];
                return Semantics(
                  label: l.demoAvatarNumber(index + 1),
                  selected: _avatar == avatar,
                  button: true,
                  child: InkWell(
                    key: ValueKey('v2-create-avatar-${avatar.name}'),
                    customBorder: const CircleBorder(),
                    onTap: _busy
                        ? null
                        : () => setState(() => _avatar = avatar),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _avatar == avatar
                              ? const Color(0xFFE9E3F8)
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        _avatarAsset(avatar),
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
                  const SizedBox(height: 20),
                  Text(l.v2MyColor, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(
                        36.0,
                        (constraints.maxWidth - 28) / 8,
                      );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final color in _colors)
                            Semantics(
                              label: l.v2MyColor,
                              selected: _color == color,
                              button: true,
                              child: InkWell(
                                key: ValueKey('v2-create-color-$color'),
                                customBorder: const CircleBorder(),
                                onTap: _busy
                                    ? null
                                    : () => setState(() => _color = color),
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    color: Color(color),
                                    shape: BoxShape.circle,
                                    border: color == 0xFFFFFFFF
                                        ? Border.all(
                                            color: const Color(0xFFE5E5E5),
                                          )
                                        : null,
                                  ),
                                  child: _color == color
                                      ? const Center(
                                          child: V2Icon(
                                            'check',
                                            size: 20,
                                            color: AppColors.brand,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
}
