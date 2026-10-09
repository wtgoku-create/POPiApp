import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/ip_account_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../assets/domain/library_role.dart';

/// Selects account residents without changing any existing creation's cast.
class IpAccountRolesSheet extends ConsumerStatefulWidget {
  const IpAccountRolesSheet({
    required this.selectedIds,
    required this.onSave,
    this.selectedNames = const {},
    super.key,
  });
  final List<String> selectedIds;
  final Map<String, String> selectedNames;
  final Future<void> Function(List<String>, String) onSave;

  @override
  ConsumerState<IpAccountRolesSheet> createState() =>
      _IpAccountRolesSheetState();
}

class _IpAccountRolesSheetState extends ConsumerState<IpAccountRolesSheet> {
  late final String? _ownerId;
  late final _selected = [...widget.selectedIds];
  late Future<List<LibraryRole>> _roles;
  String _category = 'user';
  bool _saving = false;
  bool _failed = false;
  String _requestId = const Uuid().v4();
  CancelToken? _rolesToken;
  final _names = <String, String>{};

  @override
  void initState() {
    super.initState();
    _ownerId = ref.read(userProvider)?.id;
    _names.addAll(widget.selectedNames);
    _load();
  }

  @override
  void dispose() {
    _rolesToken?.cancel();
    super.dispose();
  }

  void _load() {
    _rolesToken?.cancel();
    _rolesToken = CancelToken();
    _roles = ref
        .read(ipAccountRepositoryProvider)
        .availableRoles(_category, cancelToken: _rolesToken);
  }

  Future<void> _save() async {
    if (_saving || ref.read(userProvider)?.id != _ownerId) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(List.unmodifiable(_selected), _requestId);
      if (mounted && ref.read(userProvider)?.id == _ownerId) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, id) {
      if (id != _ownerId && mounted) Navigator.of(context).pop(false);
    });
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.ipAccountManageRoles,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'user', label: Text(l10n.myRoles)),
                    ButtonSegment(
                      value: 'official',
                      label: Text(l10n.officialRoles),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _category = value.single;
                          _load();
                        }),
                ),
                const SizedBox(height: 10),
                if (_selected.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final id in _selected)
                            InputChip(
                              label: Text(_names[id] ?? id),
                              deleteButtonTooltipMessage: l10n.delete,
                              onDeleted: _saving
                                  ? null
                                  : () => setState(() {
                                      _selected.remove(id);
                                      _requestId = const Uuid().v4();
                                    }),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: FutureBuilder<List<LibraryRole>>(
                    future: _roles,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: TextButton(
                            onPressed: () => setState(_load),
                            child: Text(l10n.retry),
                          ),
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final roles = snapshot.data ?? [];
                      if (roles.isEmpty) {
                        return Center(child: Text(l10n.ipAccountNoRoles));
                      }
                      return ListView(
                        children: [
                          for (final role in roles)
                            CheckboxListTile(
                              key: Key('ip-account-select-role-${role.id}'),
                              title: Text(role.title),
                              subtitle: role.description.isEmpty
                                  ? null
                                  : Text(
                                      role.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              value: _selected.contains(role.id),
                              onChanged:
                                  _saving ||
                                      (!_selected.contains(role.id) &&
                                          _selected.length >= 20)
                                  ? null
                                  : (selected) => setState(() {
                                      _names[role.id] = role.title;
                                      selected!
                                          ? _selected.add(role.id)
                                          : _selected.remove(role.id);
                                      _requestId = const Uuid().v4();
                                    }),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (_selected.length >= 20) Text(l10n.ipAccountRoleLimit),
                if (_failed)
                  Text(
                    l10n.networkRequestFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('ip-account-roles-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.ipAccountSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
