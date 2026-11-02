import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/demo_file_picker.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import '../domain/demo_upload_file.dart';
import 'widgets/demo_widgets.dart';

/// Keeps the selection and successful uploads intact when a batch is interrupted.
class DemoFileImportSheet extends StatefulWidget {
  const DemoFileImportSheet({
    required this.repository,
    this.pickFiles = pickDemoAssetFiles,
    this.pickPhotos = pickDemoPhotos,
    this.takePhoto = takeDemoPhoto,
    this.recoverPhotos = recoverLostDemoPhotos,
    this.discardRecoveredPhotos = discardLostDemoPhotos,
    this.mobileMediaSources,
    this.recoverLostCamera,
    this.cameraRecoveryScope,
    this.onImported,
    super.key,
  });

  final DemoRepository repository;
  final Future<List<DemoUploadFile>> Function() pickFiles;
  final Future<List<DemoUploadFile>> Function() pickPhotos;
  final Future<DemoUploadFile?> Function() takePhoto;
  final Future<List<DemoUploadFile>> Function() recoverPhotos;
  final Future<void> Function() discardRecoveredPhotos;
  final bool? mobileMediaSources;
  final bool? recoverLostCamera;
  final String? cameraRecoveryScope;
  final ValueChanged<List<DemoAsset>>? onImported;

  @override
  State<DemoFileImportSheet> createState() => _DemoFileImportSheetState();
}

class _DemoFileImportSheetState extends State<DemoFileImportSheet> {
  final _files = <DemoUploadFile>[];
  final _uploaded = <String>{};
  final _imagePreviews = <String, Uint8List>{};
  final _loadingPreviews = <String>{};
  final _failedPreviews = <String>{};
  Future<void> _previewQueue = Future.value();
  bool _picking = false;
  bool _uploading = false;
  String? _uploadingId;

  bool get _showMobileMediaSources =>
      widget.mobileMediaSources ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));
  bool get _shouldRecoverLostCamera =>
      widget.recoverLostCamera ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreHeldCameraDraft();
    });
    if (_shouldRecoverLostCamera && widget.cameraRecoveryScope != null) {
      unawaited(_recoverCameraDraft());
    }
  }

  Future<void> _recoverCameraDraft() async {
    final owner = widget.cameraRecoveryScope;
    if (owner == null || widget.repository.pendingCameraCaptureOwner != owner) {
      return;
    }
    setState(() => _picking = true);
    try {
      final files = await widget.recoverPhotos();
      widget.repository.holdRecoveredCameraDraft(owner, files);
      if (!mounted) return;
      final restored = _restoreHeldCameraDraft();
      if (restored) {
        AppToast.info(context, AppLocalizations.of(context)!.cameraRecovered);
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, _errorMessage(error, selecting: true));
      }
    } finally {
      await widget.repository.finishCameraCapture(owner);
      if (mounted) setState(() => _picking = false);
    }
  }

  String _errorMessage(Object error, {bool selecting = false}) {
    final l = AppLocalizations.of(context)!;
    if (error is DemoUploadException) {
      return switch (error.code.toLowerCase()) {
        'empty_file' => l.demoUploadEmptyFile,
        'file_too_large' => l.demoUploadTooLarge,
        'attachment_limit' => l.demoAttachmentLimit,
        'attachments_too_large' => l.demoAttachmentTooLarge,
        'unsupported_type' => l.demoUploadUnsupported,
        'invalid_name' ||
        'invalid_content' ||
        'size_mismatch' => l.demoUploadInvalidFile,
        _ => l.demoUploadFailed,
      };
    }
    return selecting ? l.demoFileSelectionFailed : l.demoUploadFailed;
  }

  Future<void> _pick() async {
    if (_picking || _uploading) return;
    setState(() => _picking = true);
    try {
      final files = await widget.pickFiles();
      if (mounted) _addFiles(files);
    } catch (error) {
      if (mounted) {
        if (error is DemoUploadException) _addFiles(error.acceptedFiles);
        AppToast.error(context, _errorMessage(error, selecting: true));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickPhotos() async {
    if (_picking || _uploading) return;
    setState(() => _picking = true);
    try {
      final files = await widget.pickPhotos();
      if (mounted) _addFiles(files);
    } catch (error) {
      if (!mounted) return;
      if (error is DemoUploadException) _addFiles(error.acceptedFiles);
      AppToast.error(context, _errorMessage(error, selecting: true));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_picking || _uploading) return;
    final owner = widget.cameraRecoveryScope;
    if (owner != null && !await _claimCameraOwner(owner)) return;
    setState(() => _picking = true);
    try {
      final file = await widget.takePhoto();
      if (file != null && owner != null) {
        widget.repository.holdRecoveredCameraDraft(owner, [file]);
      }
      if (!mounted || file == null) return;
      if (owner == null) {
        _addFiles([file]);
      } else {
        _restoreHeldCameraDraft();
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      AppToast.error(context, switch (error.code) {
        'camera_access_denied' ||
        'camera_access_restricted' => l.cameraPermissionDenied,
        'no_available_camera' => l.cameraUnavailable,
        _ => l.demoFileSelectionFailed,
      });
    } catch (error) {
      if (mounted) {
        AppToast.error(context, _errorMessage(error, selecting: true));
      }
    } finally {
      if (owner != null) await widget.repository.finishCameraCapture(owner);
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<bool> _claimCameraOwner(String owner) async {
    if (widget.repository.hasRecoveredCameraDraft(owner)) {
      _restoreHeldCameraDraft();
      return false;
    }
    final claimed = await widget.repository.beginCameraCapture(owner);
    if (!mounted) {
      if (claimed) await widget.repository.finishCameraCapture(owner);
      return false;
    }
    if (claimed) return true;
    if (!mounted) return false;
    final existing = widget.repository.pendingCameraCaptureOwner;
    if (existing == null) return widget.repository.beginCameraCapture(owner);
    final l = AppLocalizations.of(context)!;
    final discard = await AppDialog.confirm(
      context: context,
      title: l.cameraRecoveryPendingTitle,
      description: l.cameraRecoveryPending,
      cancelLabel: l.cancel,
      confirmLabel: l.cameraRecoveryDiscard,
      confirmKey: const Key('camera-recovery-discard'),
      destructive: true,
    );
    if (discard != true) return false;
    try {
      await widget.discardRecoveredPhotos();
    } catch (_) {
      if (mounted) AppToast.error(context, l.demoFileSelectionFailed);
      return false;
    }
    await widget.repository.finishCameraCapture(existing);
    final reclaimed = await widget.repository.beginCameraCapture(owner);
    if (!mounted) {
      if (reclaimed) await widget.repository.finishCameraCapture(owner);
      return false;
    }
    return reclaimed;
  }

  bool _restoreHeldCameraDraft() {
    final owner = widget.cameraRecoveryScope;
    if (owner == null) return false;
    final held = widget.repository.takeRecoveredCameraDraft(owner);
    if (held.isEmpty) return false;
    if (_addFiles(held)) return true;
    widget.repository.holdRecoveredCameraDraft(owner, held);
    return false;
  }

  bool _addFiles(List<DemoUploadFile> files) {
    final selected = _files.map((file) => file.clientRequestId).toSet();
    final added = files
        .where((file) => selected.add(file.clientRequestId))
        .toList();
    final next = [..._files, ...added];
    var totalBytes = 0;
    var imageBytes = 0;
    for (final file in next) {
      totalBytes += file.sizeBytes;
      if (file.kind == DemoAssetKind.image) imageBytes += file.sizeBytes;
    }
    if (next.length > DemoUploadFile.messageAttachmentLimit) {
      AppToast.error(
        context,
        _errorMessage(const DemoUploadException('ATTACHMENT_LIMIT')),
      );
      return false;
    }
    if (totalBytes > DemoUploadFile.messageAttachmentTotalLimitBytes ||
        imageBytes > DemoUploadFile.messageImageTotalLimitBytes) {
      AppToast.error(
        context,
        _errorMessage(const DemoUploadException('ATTACHMENTS_TOO_LARGE')),
      );
      return false;
    }
    setState(() => _files.addAll(added));
    for (final file in added) {
      _previewQueue = _previewQueue.then((_) => _loadImagePreview(file));
    }
    return true;
  }

  Future<void> _loadImagePreview(DemoUploadFile file) async {
    if (!mounted ||
        !_files.any(
          (selected) => selected.clientRequestId == file.clientRequestId,
        ) ||
        file.kind != DemoAssetKind.image ||
        file.sizeBytes > DemoUploadFile.imageLimitBytes ||
        _imagePreviews.containsKey(file.clientRequestId) ||
        _loadingPreviews.contains(file.clientRequestId) ||
        _failedPreviews.contains(file.clientRequestId)) {
      return;
    }
    _loadingPreviews.add(file.clientRequestId);
    try {
      final sourceBytes = await file.readBytes();
      ui.ImmutableBuffer? buffer;
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      ui.Image? image;
      Uint8List thumbnailBytes;
      try {
        buffer = await ui.ImmutableBuffer.fromUint8List(sourceBytes);
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final scale = descriptor.width <= 132 && descriptor.height <= 132
            ? 1.0
            : 132 /
                  (descriptor.width > descriptor.height
                      ? descriptor.width
                      : descriptor.height);
        final targetWidth = (descriptor.width * scale).round().clamp(1, 132);
        final targetHeight = (descriptor.height * scale).round().clamp(1, 132);
        codec = await descriptor.instantiateCodec(
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
        final frame = await codec.getNextFrame();
        image = frame.image;
        final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
        if (encoded == null) {
          throw const FormatException('preview encode failed');
        }
        thumbnailBytes = encoded.buffer.asUint8List(
          encoded.offsetInBytes,
          encoded.lengthInBytes,
        );
      } finally {
        image?.dispose();
        codec?.dispose();
        descriptor?.dispose();
        buffer?.dispose();
      }
      if (!mounted ||
          !_files.any(
            (selected) => selected.clientRequestId == file.clientRequestId,
          )) {
        return;
      }
      setState(() => _imagePreviews[file.clientRequestId] = thumbnailBytes);
    } catch (_) {
      if (mounted &&
          _files.any(
            (selected) => selected.clientRequestId == file.clientRequestId,
          )) {
        setState(() => _failedPreviews.add(file.clientRequestId));
      }
    } finally {
      _loadingPreviews.remove(file.clientRequestId);
    }
  }

  void _removeFile(int index) {
    final id = _files[index].clientRequestId;
    setState(() {
      _files.removeAt(index);
      _imagePreviews.remove(id);
      _failedPreviews.remove(id);
    });
  }

  Future<void> _upload() async {
    if (_files.isEmpty || _uploading || _picking) return;
    setState(() => _uploading = true);
    try {
      for (final file in List<DemoUploadFile>.of(_files)) {
        if (_uploaded.contains(file.clientRequestId)) {
          continue;
        }
        setState(() => _uploadingId = file.clientRequestId);
        final asset = await widget.repository.uploadFile(file);
        if (!mounted) return;
        setState(() {
          _uploaded.add(file.clientRequestId);
        });
        // Publish each accepted upload immediately. If a later file fails, the
        // successful item remains selected while the failed draft can retry.
        widget.onImported?.call([asset]);
      }
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      Navigator.of(context).pop();
      AppToast.success(context, l.demoImported);
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadingId = null;
        });
      }
    }
  }

  String _size(AppLocalizations l, int bytes) => bytes >= 1024 * 1024
      ? l.demoFileSizeMb((bytes / (1024 * 1024)).toStringAsFixed(1))
      : bytes >= 1024
      ? l.demoFileSizeKb((bytes / 1024).toStringAsFixed(1))
      : l.demoFileSizeBytes(bytes);

  String _typeLabel(AppLocalizations l, DemoAssetKind kind) => switch (kind) {
    DemoAssetKind.image => l.demoImages,
    DemoAssetKind.video => l.demoVideos,
    DemoAssetKind.script => l.demoScripts,
    DemoAssetKind.audio => l.demoAudio,
  };

  String _fileTypeLabel(AppLocalizations l, DemoUploadFile file) =>
      DemoUploadFile.isDocumentMimeType(file.mimeType)
      ? l.demoDocuments
      : _typeLabel(l, file.kind);

  String _extension(DemoUploadFile file) {
    final dot = file.name.lastIndexOf('.');
    if (dot >= 0 && dot < file.name.length - 1) {
      return file.name.substring(dot + 1).toUpperCase();
    }
    return file.mimeType.split('/').last.toUpperCase();
  }

  String _metadata(AppLocalizations l, DemoUploadFile file) {
    return <String>[
      _fileTypeLabel(l, file),
      _extension(file),
      _size(l, file.sizeBytes),
    ].join(' · ');
  }

  Widget _filePreview(DemoUploadFile file) {
    final bytes = _imagePreviews[file.clientRequestId];
    final fallback = Center(
      child: DemoIcon(file.kind.name, size: 22, color: AppColors.brand),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: bytes == null
            ? fallback
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_uploading && !_picking,
      child: DemoSheetBody(
        uploadLayout: true,
        title: l.demoUpload,
        footer: DemoPrimaryButton(
          label: l.demoUploadLibrary,
          busy: _uploading,
          onPressed: _files.isEmpty || _picking ? null : _upload,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              key: const Key('demo-import-picker'),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.light
                        ? const [Color(0xFFF5F3FD), Color(0xFFFAF5F8)]
                        : [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                          ],
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _picking || _uploading ? null : _pick,
                  child: SizedBox(
                    height: 158,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 25,
                          child: _picking
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const DemoIcon(
                                  'upload',
                                  size: 25,
                                  color: AppColors.brand,
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.demoSelectFiles,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.demoFileTypes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: .6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            l.demoDocumentLimitHint,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: .6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showMobileMediaSources) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('demo-import-gallery'),
                      onPressed: _picking || _uploading ? null : _pickPhotos,
                      icon: const DemoIcon('image', size: 20),
                      label: Text(l.gallery),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('demo-import-camera'),
                      onPressed: _picking || _uploading ? null : _takePhoto,
                      icon: AppSvgIcon.asset(
                        'attachment_camera',
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      label: Text(l.attachmentCamera),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l.photoCompatibilityHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              l.demoSelectedFiles(_files.length),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                key: const Key('demo-upload-files'),
                padding: const EdgeInsets.only(bottom: 104),
                itemCount: _files.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final ready = _uploaded.contains(file.clientRequestId);
                  return Container(
                    key: ValueKey('demo-upload-file-${file.clientRequestId}'),
                    constraints: const BoxConstraints(minHeight: 67),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: demoSurface(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 44,
                          child: _filePreview(file),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _metadata(l, file),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: .6),
                                      ),
                                    ),
                                  ),
                                  if (ready) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      DemoUploadFile.isDocumentMimeType(
                                            file.mimeType,
                                          )
                                          ? l.demoDocumentReady
                                          : l.demoFileUploaded,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox.square(
                          dimension: 36,
                          child: _uploadingId == file.clientRequestId && !ready
                              ? Tooltip(
                                  message:
                                      DemoUploadFile.isDocumentMimeType(
                                        file.mimeType,
                                      )
                                      ? l.demoDocumentParsing
                                      : l.demoUpload,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : ready
                              ? Tooltip(
                                  message: l.demoFileUploaded,
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.success,
                                    size: 22,
                                  ),
                                )
                              : IconButton(
                                  key: ValueKey(
                                    'demo-upload-remove-${file.clientRequestId}',
                                  ),
                                  tooltip: l.delete,
                                  padding: EdgeInsets.zero,
                                  onPressed: _uploading || _picking
                                      ? null
                                      : () => _removeFile(index),
                                  icon: const DemoIcon(
                                    'close',
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                        ),
                      ],
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
