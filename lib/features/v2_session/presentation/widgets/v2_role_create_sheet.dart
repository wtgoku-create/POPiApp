import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../v2_shared/data/v2_file_picker.dart';
import '../../../v2_shared/data/v2_repository.dart';
import '../../../v2_shared/domain/v2_models.dart';
import '../../../v2_shared/domain/v2_upload_file.dart';
import '../../../v2_shared/presentation/widgets/v2_widgets.dart';

/// Creates a business character with instructions and optional reference images.
class V2RoleCreateSheet extends StatefulWidget {
  const V2RoleCreateSheet({required this.repository, super.key});
  final V2Repository repository;
  @override
  State<V2RoleCreateSheet> createState() => _V2RoleCreateSheetState();
}

class _V2RoleCreateSheetState extends State<V2RoleCreateSheet> {
  final _name = TextEditingController();
  final _instructions = TextEditingController();
  final List<V2UploadFile> _files = [];
  final _requestId = const Uuid().v4();
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = <V2UploadFile>[];
    await v2Perform(context, () async {
      try {
        files.addAll(await pickV2RoleImages());
      } on V2UploadException catch (error) {
        files.addAll(error.acceptedFiles);
        if (mounted) {
          AppToast.error(
            context,
            AppLocalizations.of(context)!.v2UploadInvalid,
          );
        }
      }
    });
    if (mounted) {
      setState(() {
        for (final file in files) {
          if (_files.length < 5 &&
              !_files.any((f) => f.clientRequestId == file.clientRequestId)) {
            _files.add(file);
          }
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    V2Character? role;
    final ok = await v2Perform(context, () async {
      role = await widget.repository.createRole(
        requestId: _requestId,
        name: _name.text.trim(),
        instructions: _instructions.text.trim(),
        files: List.of(_files),
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(role);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: V2SheetBody(
        title: l.demoCreateRole,
        footer: V2PrimaryButton(
          label: l.confirm,
          busy: _busy,
          onPressed:
              _name.text.trim().isEmpty ||
                  (_instructions.text.trim().isEmpty && _files.isEmpty)
              ? null
              : _save,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: 40,
              decoration: InputDecoration(labelText: l.demoName),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructions,
              enabled: !_busy,
              maxLength: 2000,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: l.v2RoleInstructions),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || _files.length >= 5 ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(l.v2RoleReferences),
            ),
            for (final file in _files)
              ListTile(
                key: ValueKey(file.clientRequestId),
                title: Text(file.name),
                trailing: IconButton(
                  tooltip: l.delete,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _files.remove(file)),
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
