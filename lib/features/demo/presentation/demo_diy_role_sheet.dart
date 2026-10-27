import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/demo_file_picker.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import '../domain/demo_upload_file.dart';
import 'widgets/demo_widgets.dart';

typedef DemoDiyRoleFilePicker = Future<List<DemoUploadFile>> Function();

class _DiyRoleCountLimit implements Exception {
  const _DiyRoleCountLimit();
}

/// Creates a reusable content role and links it to [sessionId].
Future<String?> showDemoDiyRoleSheet(
  BuildContext context,
  DemoRepository repository,
  String sessionId, {
  DemoDiyRoleFilePicker? pickFiles,
}) => DemoSheet.show<String>(
  context: context,
  builder: (_) => DemoDiyRoleSheet(
    repository: repository,
    sessionId: sessionId,
    pickFiles: pickFiles ?? pickDemoRoleImages,
  ),
);

class DemoDiyRoleSheet extends StatefulWidget {
  const DemoDiyRoleSheet({
    required this.repository,
    required this.sessionId,
    required this.pickFiles,
    super.key,
  });

  final DemoRepository repository;
  final String sessionId;
  final DemoDiyRoleFilePicker pickFiles;

  @override
  State<DemoDiyRoleSheet> createState() => _DemoDiyRoleSheetState();
}

class _DemoDiyRoleSheetState extends State<DemoDiyRoleSheet> {
  static const _imageLimit = 5;
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _files = <DemoUploadFile>[];
  final _previews = <String, Uint8List>{};
  final _uploadedAssetIds = <String, String>{};
  final _roleId = 'custom:${const Uuid().v4()}';
  bool _picking = false;
  bool _saving = false;

  bool get _hasRoleContext =>
      _description.text.trim().isNotEmpty || _files.isNotEmpty;
  bool get _canSave => _name.text.trim().isNotEmpty && _hasRoleContext;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String _errorMessage(Object error, AppLocalizations l) {
    if (error is DemoUploadException) {
      return switch (error.code.toLowerCase()) {
        'empty_file' => l.demoUploadEmptyFile,
        'file_too_large' => l.demoUploadTooLarge,
        'unsupported_type' => l.demoUploadUnsupported,
        'invalid_name' ||
        'invalid_content' ||
        'size_mismatch' => l.demoUploadInvalidFile,
        _ => l.demoUploadFailed,
      };
    }
    return l.demoUploadFailed;
  }

  Future<void> _pick() async {
    if (_picking || _saving || _files.length >= _imageLimit) return;
    setState(() => _picking = true);
    try {
      await _acceptFiles(await widget.pickFiles());
    } catch (error) {
      if (!mounted) return;
      if (error is DemoUploadException) {
        await _acceptFiles(error.acceptedFiles);
      }
      if (mounted) {
        AppToast.error(
          context,
          _errorMessage(error, AppLocalizations.of(context)!),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _acceptFiles(List<DemoUploadFile> picked) async {
    final known = _files.map((file) => file.clientRequestId).toSet();
    final availableImages = picked
        .where((file) => file.kind == DemoAssetKind.image)
        .where((file) => known.add(file.clientRequestId))
        .toList();
    final images = availableImages.take(_imageLimit - _files.length).toList();
    if (!mounted) return;
    setState(() {
      _files.addAll(images);
      if (_name.text.trim().isEmpty && images.isNotEmpty) {
        _name.text = _nameFromFile(images.first.name);
      }
    });
    if (picked.any((file) => file.kind != DemoAssetKind.image)) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.demoUploadUnsupported,
      );
    }
    if (availableImages.length > images.length) {
      AppToast.error(context, AppLocalizations.of(context)!.demoDiyRoleLimit);
    }
    for (final file in images) {
      try {
        final bytes = await _thumbnail(await file.readBytes());
        if (mounted && _files.contains(file)) {
          setState(() => _previews[file.clientRequestId] = bytes);
        }
      } catch (_) {
        // Upload validation reports the actionable error when the user saves.
      }
    }
  }

  String _nameFromFile(String name) {
    final dot = name.lastIndexOf('.');
    return (dot > 0 ? name.substring(0, dot) : name).trim();
  }

  Future<Uint8List> _thumbnail(Uint8List source) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(source);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = longest <= 160 ? 1.0 : 160 / longest;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, 160),
        targetHeight: (descriptor.height * scale).round().clamp(1, 160),
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const FormatException('preview encode failed');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void _remove(DemoUploadFile file) {
    if (_saving) return;
    setState(() {
      _files.remove(file);
      _previews.remove(file.clientRequestId);
      _uploadedAssetIds.remove(file.clientRequestId);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_saving || name.isEmpty || !_hasRoleContext) return;
    final current = widget.repository.session(widget.sessionId);
    if (!current.roles.contains(_roleId) && current.roles.length >= 5) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.roleSelectionLimit(5),
      );
      return;
    }
    setState(() => _saving = true);
    var savingProfile = false;
    try {
      for (final file in _files) {
        if (_uploadedAssetIds.containsKey(file.clientRequestId)) continue;
        final asset = await widget.repository.uploadFile(file);
        if (!mounted) return;
        setState(() => _uploadedAssetIds[file.clientRequestId] = asset.id);
      }
      final referenceAssetIds = [
        for (final file in _files) _uploadedAssetIds[file.clientRequestId]!,
      ];
      final profile = DemoRoleProfile(
        name: name,
        instructions: _description.text.trim(),
        referenceAssetIds: referenceAssetIds,
        revision: 'diy-${DateTime.now().microsecondsSinceEpoch}',
      );
      savingProfile = true;
      await widget.repository.updateSession(widget.sessionId, (session) {
        if (!session.roles.contains(_roleId) && session.roles.length >= 5) {
          throw const _DiyRoleCountLimit();
        }
        return session.copyWith(
          roles: session.roles.contains(_roleId)
              ? session.roles
              : [...session.roles, _roleId],
          roleProfiles: {...session.roleProfiles, _roleId: profile},
        );
      });
      if (mounted) Navigator.of(context).pop(_roleId);
    } on _DiyRoleCountLimit {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.roleSelectionLimit(5),
        );
        setState(() => _saving = false);
      }
    } catch (error) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        AppToast.error(
          context,
          savingProfile ? l.demoStorageError : _errorMessage(error, l),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: DemoSheetBody(
        title: l.demoDiyRoleTitle,
        footer: DemoPrimaryButton(
          key: const Key('demo-diy-role-save'),
          label: l.demoDiyRoleSave,
          busy: _saving,
          onPressed: !_canSave || _picking ? null : _save,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            TextField(
              key: const Key('demo-diy-role-name'),
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(l.demoDiyRoleNameHint),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('demo-diy-role-description'),
              controller: _description,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              maxLength: 12000,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(l.demoDiyRoleDescriptionHint),
            ),
            const SizedBox(height: 12),
            Text(
              l.demoReferenceImagesHint,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            if (_files.isNotEmpty)
              Wrap(
                key: const Key('demo-diy-role-files'),
                spacing: 8,
                runSpacing: 8,
                children: [for (final file in _files) _fileTile(file)],
              ),
            if (_files.isNotEmpty) const SizedBox(height: 10),
            _DiyImageButton(
              busy: _picking,
              enabled: !_saving && _files.length < _imageLimit,
              label: l.demoSelectRoleImages,
              onPressed: _pick,
            ),
            const SizedBox(height: 6),
            Text(
              l.demoDiyRoleLimit,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: demoTint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );

  Widget _fileTile(DemoUploadFile file) {
    final preview = _previews[file.clientRequestId];
    return SizedBox(
      key: ValueKey('demo-diy-file-${file.clientRequestId}'),
      width: 92,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: demoTint,
                  child: SizedBox.square(
                    dimension: 76,
                    child: preview == null
                        ? const Center(
                            child: DemoIcon('image', color: AppColors.brand),
                          )
                        : Image.memory(
                            preview,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: DemoIcon('image', color: AppColors.brand),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  key: ValueKey('demo-diy-remove-${file.clientRequestId}'),
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : () => _remove(file),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
          Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DiyImageButton extends StatelessWidget {
  const _DiyImageButton({
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: OutlinedButton.icon(
      key: const Key('demo-diy-role-picker'),
      onPressed: enabled && !busy ? onPressed : null,
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const DemoIcon('upload', size: 18, color: AppColors.brand),
      label: Text(label),
    ),
  );
}
