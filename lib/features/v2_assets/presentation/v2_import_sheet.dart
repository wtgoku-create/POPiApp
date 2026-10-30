import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../v2_shared/data/v2_file_picker.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_upload_file.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';

/// Retains selected files until each library upload is accepted.
class V2ImportSheet extends StatefulWidget {
  const V2ImportSheet({required this.repository, super.key});
  final V2Repository repository;
  @override
  State<V2ImportSheet> createState() => _V2ImportSheetState();
}

class _V2ImportSheetState extends State<V2ImportSheet> {
  final List<V2UploadFile> _files = [];
  bool _busy = false;
  Future<void> _pick() async {
    final files = <V2UploadFile>[];
    await v2Perform(context, () async {
      try {
        files.addAll(await pickV2AssetFiles());
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
          if (!_files.any((f) => f.clientRequestId == file.clientRequestId)) {
            _files.add(file);
          }
        }
      });
    }
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    final ok = await v2Perform(context, () async {
      for (final file in List.of(_files)) {
        await widget.repository.uploadFile(file);
        if (!mounted) return;
        setState(() => _files.remove(file));
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
      AppToast.success(context, AppLocalizations.of(context)!.demoImported);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: V2SheetBody(
        title: l.demoUpload,
        footer: V2PrimaryButton(
          label: l.demoUploadLibrary,
          busy: _busy,
          onPressed: _files.isEmpty ? null : _upload,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l.demoSelectFiles),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.demoSelectedFiles(_files.length)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                padding: const EdgeInsets.only(bottom: 110),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return ListTile(
                    key: ValueKey(file.clientRequestId),
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${(file.sizeBytes / 1024).ceil()} KB'),
                    trailing: IconButton(
                      tooltip: l.delete,
                      onPressed: _busy
                          ? null
                          : () => setState(() => _files.removeAt(index)),
                      icon: const Icon(Icons.close),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
