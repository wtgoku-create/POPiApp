import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/ip_account_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/type/account_input_type.dart';
import '../../../../shared/widgets/app_expanded_text_field.dart';
import '../../domain/account_preferences.dart';
import '../../domain/ip_account_home.dart';

/// Limits account edits to the fields displayed in the selected overview card.
enum AccountPreferencesEditScope { preferences, positioning }

/// Shared create/edit form using the preference catalog and limits from the API.
class AccountPreferencesSheet extends ConsumerStatefulWidget {
  const AccountPreferencesSheet({
    this.account,
    this.editScope = AccountPreferencesEditScope.preferences,
    super.key,
  }) : assert(
         account != null ||
             editScope == AccountPreferencesEditScope.preferences,
       );
  final IpAccountHome? account;
  final AccountPreferencesEditScope editScope;
  @override
  ConsumerState<AccountPreferencesSheet> createState() =>
      _AccountPreferencesSheetState();
}

class _AccountPreferencesSheetState
    extends ConsumerState<AccountPreferencesSheet> {
  final _token = CancelToken();
  late final String? _owner;
  late final _title = TextEditingController(text: widget.account?.title ?? '');
  late final _prompt = TextEditingController(
    text: widget.account?.userPrompt ?? '',
  );
  final _values = <String, List<String>>{};
  final _custom = <String, TextEditingController>{};
  final _lastCustomText = <String, String>{};
  List<AccountPreferenceStep>? _steps;
  bool _saving = false;
  String? _error;
  String? _requestId;
  String? _submitted;

  bool get _creating => widget.account == null;
  bool get _editingPositioning =>
      !_creating && widget.editScope == AccountPreferencesEditScope.positioning;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(userProvider)?.id;
    unawaited(_load());
  }

  @override
  void dispose() {
    _token.cancel();
    _title.dispose();
    _prompt.dispose();
    for (final c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _steps = null;
      _error = null;
    });
    if (_editingPositioning) {
      setState(() => _steps = const []);
      return;
    }
    try {
      final steps = await ref
          .read(ipAccountRepositoryProvider)
          .preferenceOptions(cancelToken: _token);
      if (!mounted || _token.isCancelled) return;
      final l10n = AppLocalizations.of(context)!;
      final all = [
        ...steps.where(
          (step) =>
              _creating ||
              const {
                'contentDirections',
                'audienceFeelings',
                'presentationFormats',
                'targetAudience',
              }.contains(step.key),
        ),
        AccountPreferenceStep(
          key: 'creativeConstraints',
          title: l10n.accountConstraints,
          maxNameBytes: 2000,
        ),
      ];
      for (final step in all) {
        _values.putIfAbsent(
          step.key,
          () => [...?widget.account?.selections(step.key)],
        );
        _custom.putIfAbsent(step.key, () {
          final values = _values[step.key]!;
          final customOnly =
              step.allowCustom &&
              values.length == 1 &&
              !step.options.any((option) => option.name == values.single);
          final controller = TextEditingController(
            text: customOnly ? values.single : '',
          );
          _lastCustomText[step.key] = controller.text;
          controller.addListener(() => _customChanged(step));
          return controller;
        });
      }
      setState(() => _steps = all);
    } catch (_) {
      if (mounted && !_token.isCancelled) {
        setState(
          () => _error = AppLocalizations.of(context)!.networkRequestFailed,
        );
      }
    }
  }

  void _customChanged(AccountPreferenceStep step) {
    final text = _custom[step.key]!.text;
    if (text == _lastCustomText[step.key]) return;
    _lastCustomText[step.key] = text;
    setState(() {
      _values[step.key] = text.trim().isEmpty ? [] : [text.trim()];
      _error = null;
    });
  }

  void _select(AccountPreferenceStep step, String value, bool selected) {
    final values = selected
        ? [
            ..._values[step.key]!.where(
              (name) => step.options.any((option) => option.name == name),
            ),
            value,
          ]
        : _values[step.key]!.where((name) => name != value).toList();
    if (selected && !step.accepts(values)) {
      setState(
        () => _error = AppLocalizations.of(context)!.accountInputInvalid,
      );
      return;
    }
    _custom[step.key]!.clear();
    setState(() {
      _values[step.key] = values;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _steps == null || ref.read(userProvider)?.id != _owner) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    if (_creating &&
        (title.characters.length > AccountInputLimits.nicknameCharacters ||
            utf8.encode(title).length > AccountInputLimits.nicknameBytes)) {
      setState(() => _error = l10n.accountTitleInvalid);
      return;
    }
    if (_steps!.any((s) => !s.accepts(_values[s.key]!))) {
      setState(() => _error = l10n.accountInputInvalid);
      return;
    }
    // Only changed groups are patched; unknown server preferences stay intact.
    final preferences = <String, Object?>{
      for (final step in _steps!)
        if ((widget.account == null && _values[step.key]!.isNotEmpty) ||
            (widget.account != null &&
                !listEquals(
                  _values[step.key],
                  widget.account!.selections(step.key),
                )))
          step.key: List<String>.of(_values[step.key]!),
    };
    final snapshot = jsonEncode([title, preferences, _prompt.text]);
    if (snapshot != _submitted) {
      _submitted = snapshot;
      _requestId = const Uuid().v4();
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(ipAccountRepositoryProvider);
      String id;
      if (widget.account == null) {
        id = await repository.create(
          requestId: _requestId!,
          title: title.isEmpty ? null : title,
          preferences: preferences.isEmpty ? null : preferences,
          userPrompt: _prompt.text.isEmpty ? null : _prompt.text,
          cancelToken: _token,
        );
      } else {
        id = widget.account!.id;
        final userPrompt =
            _editingPositioning && _prompt.text != widget.account!.userPrompt
            ? _prompt.text
            : null;
        if (preferences.isNotEmpty || userPrompt != null) {
          await repository.update(
            id,
            preferences: preferences.isEmpty ? null : preferences,
            userPrompt: userPrompt,
            cancelToken: _token,
          );
        }
      }
      if (mounted &&
          !_token.isCancelled &&
          ref.read(userProvider)?.id == _owner) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted && !_token.isCancelled) {
        setState(
          () => _error = e is ApiException
              ? e.message ?? l10n.networkRequestFailed
              : l10n.networkRequestFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, id) {
      if (id != _owner && mounted) {
        _token.cancel();
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context);
        navigator.popUntil((candidate) => candidate == route);
        navigator.pop();
      }
    });
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  _creating
                      ? l10n.accountCreate
                      : _editingPositioning
                      ? l10n.accountUserPrompt
                      : l10n.ipAccountPreferences,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const Key('account-form-scroll'),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _form(l10n),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                ),
                child: Padding(
                  key: const Key('account-form-actions'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _actions(l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_steps == null && _error == null)
        const Center(child: CircularProgressIndicator()),
      if (_steps == null && _error != null)
        TextButton(onPressed: _load, child: Text(l10n.retry)),
      if (_steps != null) ...[
        if (_creating) ...[
          Text(
            l10n.ipAccountNickname,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          AppExpandedTextField(
            fieldKey: const Key('account-form-title'),
            controller: _title,
            hint: l10n.ipNicknameHint,
            limit: AccountInputLimits.nicknameCharacters,
            maxBytes: AccountInputLimits.nicknameBytes,
            nickname: true,
            readOnly: _saving,
            editInSheet: false,
          ),
          const SizedBox(height: 20),
        ],
        for (final step in _steps!) ...[
          Text(switch (step.key) {
            'contentDirections' => l10n.ipContentDirection,
            'audienceFeelings' => l10n.ipAudienceFeeling,
            'presentationFormats' => l10n.ipPresentation,
            'targetAudience' => l10n.ipTargetAudience,
            'creativeConstraints' => l10n.accountConstraints,
            _ => step.title,
          }, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in step.options)
                Tooltip(
                  message: option.description,
                  child: FilterChip(
                    label: Text(option.name),
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .1),
                    labelStyle: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    selected: _values[step.key]!.contains(option.name),
                    onSelected: _saving
                        ? null
                        : (selected) => _select(step, option.name, selected),
                  ),
                ),
              for (final value in _values[step.key]!.where(
                (v) =>
                    _custom[step.key]!.text.trim().isEmpty &&
                    !step.options.any((o) => o.name == v),
              ))
                InputChip(
                  label: Text(value),
                  onDeleted: _saving
                      ? null
                      : () => setState(() => _values[step.key]!.remove(value)),
                ),
            ],
          ),
          if (step.allowCustom) ...[
            if (step.options.isNotEmpty || _values[step.key]!.isNotEmpty)
              const SizedBox(height: 12),
            AppExpandedTextField(
              key: Key('account-custom-${step.key}'),
              controller: _custom[step.key]!,
              hint: l10n.ipCustomHint,
              limit: AccountInputLimits.customCharacters,
              maxBytes: step.maxNameBytes,
              readOnly: _saving,
            ),
          ],
          const SizedBox(height: 24),
        ],
        if (_creating || _editingPositioning) ...[
          if (_creating) ...[
            Text(
              l10n.accountUserPrompt,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
          _positioningInput(l10n),
          const SizedBox(height: 16),
        ],
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 8),
    ],
  );

  Widget _positioningInput(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 220,
      child: TextField(
        key: const Key('account-form-prompt'),
        controller: _prompt,
        enabled: !_saving,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: TextStyle(fontSize: 16, height: 1.5, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: l10n.accountPositioningHint,
          hintStyle: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
          filled: true,
          fillColor: colors.brightness == Brightness.dark
              ? colors.surfaceContainerHigh
              : const Color(0xFFF0F4F9),
          contentPadding: const EdgeInsets.all(16),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    );
  }

  Widget _actions(AppLocalizations l10n) => Row(
    children: [
      Expanded(
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 50),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: .05),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16),
          ),
          key: const Key('ip-account-edit-save'),
          onPressed: _saving || _steps == null ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.ipAccountSave),
        ),
      ),
    ],
  );
}
