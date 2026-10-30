import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    this.onImported,
    super.key,
  });

  final DemoRepository repository;
  final Future<List<DemoUploadFile>> Function() pickFiles;
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
  BusinessUploadPhase _phase = BusinessUploadPhase.pending;
  double _progress = 0;

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

  void _addFiles(List<DemoUploadFile> files) {
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
      return;
    }
    if (totalBytes > DemoUploadFile.messageAttachmentTotalLimitBytes ||
        imageBytes > DemoUploadFile.messageImageTotalLimitBytes) {
      AppToast.error(
        context,
        _errorMessage(const DemoUploadException('ATTACHMENTS_TOO_LARGE')),
      );
      return;
    }
    setState(() => _files.addAll(added));
    for (final file in added) {
      _previewQueue = _previewQueue.then((_) => _loadImagePreview(file));
    }
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
        final asset = await widget.repository.uploadFile(
          file,
          onProgress: (phase, progress) {
            if (mounted) {
              setState(() {
                _phase = phase;
                _progress = progress;
              });
            }
          },
        );
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
      if (mounted && !(error is DioException && CancelToken.isCancel(error))) {
        AppToast.error(context, _errorMessage(error));
      }
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
                                      _uploadingId == file.clientRequestId &&
                                              widget
                                                  .repository
                                                  .supportsDirectUpload
                                          ? switch (_phase) {
                                              BusinessUploadPhase.pending =>
                                                l.demoUploadPending,
                                              BusinessUploadPhase.uploading =>
                                                '${(_progress * 100).round()}%',
                                              BusinessUploadPhase.verifying =>
                                                l.demoUploadVerifying,
                                              BusinessUploadPhase.ready =>
                                                l.demoFileUploaded,
                                            }
                                          : _metadata(l, file),
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
                              ? IconButton(
                                  tooltip:
                                      widget.repository.supportsDirectUpload
                                      ? l.cancel
                                      : DemoUploadFile.isDocumentMimeType(
                                          file.mimeType,
                                        )
                                      ? l.demoDocumentParsing
                                      : l.demoUpload,
                                  onPressed:
                                      !widget.repository.supportsDirectUpload
                                      ? null
                                      : () =>
                                            widget.repository.cancelFileUpload(
                                              file.clientRequestId,
                                            ),
                                  icon: SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value:
                                          _phase ==
                                              BusinessUploadPhase.uploading
                                          ? _progress
                                          : null,
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
