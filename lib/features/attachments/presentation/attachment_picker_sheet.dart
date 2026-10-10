import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/legal_document_links.dart';
import '../../assets/domain/library_role.dart';
import '../../assets/domain/library_work.dart';
import '../../assets/presentation/asset_selection_sheet.dart';
import '../../assets/presentation/role_selection_sheet.dart';
import '../data/device_gallery_repository.dart';
import '../domain/gallery_repository.dart';

class AttachmentPickerResult {
  const AttachmentPickerResult.images(this.images)
    : roles = null,
      assets = null;
  const AttachmentPickerResult.selection({
    required this.images,
    this.roles,
    this.assets,
  });

  final List<XFile> images;
  final List<LibraryRole>? roles;
  final List<LibraryWork>? assets;
}

class AttachmentPickerSheet extends StatefulWidget {
  const AttachmentPickerSheet({
    required this.limit,
    this.pickImages,
    this.repository,
    this.selectedRoles = const [],
    this.selectedAssets = const [],
    super.key,
  });

  final int limit;
  final Future<List<XFile>> Function()? pickImages;
  final GalleryRepository? repository;
  final List<LibraryRole> selectedRoles;
  final List<LibraryWork> selectedAssets;

  static Future<AttachmentPickerResult?> show({
    required BuildContext context,
    required int limit,
    Future<List<XFile>> Function()? pickImages,
    GalleryRepository? repository,
    List<LibraryRole> selectedRoles = const [],
    List<LibraryWork> selectedAssets = const [],
  }) => AppSheet.show<AttachmentPickerResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
    ),
    builder: (_) => AttachmentPickerSheet(
      limit: limit,
      pickImages: pickImages,
      repository: repository,
      selectedRoles: selectedRoles,
      selectedAssets: selectedAssets,
    ),
  );

  @override
  State<AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<AttachmentPickerSheet>
    with WidgetsBindingObserver {
  static const _pageSize = 60;
  final _scroll = ScrollController();
  final _selected = <String, _Photo>{};
  final _imported = <_Photo>[];
  List<_Photo> _photos = [];
  late final GalleryRepository _repository;
  StreamSubscription<void>? _changes;
  GalleryAccess? _access;
  bool _loading = false;
  bool _moreLoading = false;
  bool _failed = false;
  bool _pageFailed = false;
  bool _hasMore = false;
  bool _busy = false;
  bool _refreshPending = false;
  int _page = 0;
  int _generation = 0;

  bool get _usesLibrary =>
      widget.pickImages == null && _repository.supportsLibrary;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DeviceGalleryRepository();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_loadNearEnd);
    if (_usesLibrary) {
      _changes = _repository.changes.listen(
        (_) => _refresh(),
        onError: (Object _) {},
      );
      _refresh(request: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _usesLibrary) _refresh();
  }

  Future<void> _refresh({bool request = false}) async {
    if (!mounted) return;
    if (_busy || _loading) {
      _refreshPending = true;
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _pageFailed = false;
      _moreLoading = false;
    });
    try {
      final access = await _repository.permission(request: request);
      final allowed =
          access == GalleryAccess.full || access == GalleryAccess.limited;
      final photos = allowed
          ? await _repository.loadPage(page: 0, size: _pageSize)
          : <GalleryPhoto>[];
      final revoked = <String>[];
      for (final entry in _selected.entries.toList()) {
        final photo = entry.value.gallery;
        if (photo != null &&
            (!allowed || !await _repository.isAvailable(photo))) {
          revoked.add(entry.key);
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _access = access;
        _photos = photos.map(_Photo.gallery).toList();
        for (final id in revoked) {
          _selected.remove(id);
        }
        _page = 0;
        _hasMore = photos.length == _pageSize;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _photos = [];
          _selected.removeWhere((_, photo) => photo.gallery != null);
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        _flushRefresh();
      }
    }
  }

  void _flushRefresh() {
    if (_refreshPending && !_busy && !_loading) {
      _refreshPending = false;
      _refresh();
    }
  }

  void _loadNearEnd() {
    if (_scroll.position.extentAfter < 300 && !_pageFailed) _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading || _moreLoading || _busy) return;
    final generation = _generation;
    setState(() {
      _moreLoading = true;
      _pageFailed = false;
    });
    try {
      final photos = await _repository.loadPage(
        page: _page + 1,
        size: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final existing = _photos.map((photo) => photo.id).toSet();
        _photos.addAll(
          photos.map(_Photo.gallery).where((photo) => existing.add(photo.id)),
        );
        _page++;
        _hasMore = photos.length == _pageSize;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _pageFailed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _moreLoading = false);
      }
    }
  }

  void _toggle(_Photo photo) {
    if (_busy || _loading) return;
    if (_selected.containsKey(photo.id)) {
      setState(() => _selected.remove(photo.id));
    } else if (_selected.length < widget.limit) {
      setState(() => _selected[photo.id] = photo);
    } else {
      AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
    }
  }

  Future<void> _import({bool fromFiles = false}) async {
    if (_busy) return;
    final remaining = widget.limit - _selected.length;
    if (remaining <= 0) {
      AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
      return;
    }
    setState(() => _busy = true);
    try {
      final files = fromFiles
          ? await _repository.pickImageFiles(remaining)
          : await (widget.pickImages?.call() ??
                _repository.pickImages(remaining));
      if (!mounted) return;
      setState(() {
        for (final file in files.take(remaining)) {
          final photo = _Photo.file(file);
          if (!_imported.any((item) => item.id == photo.id)) {
            _imported.insert(0, photo);
          }
          _selected[photo.id] = photo;
        }
      });
      if (files.length > remaining) {
        AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context)!.imageReadFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _flushRefresh();
      }
    }
  }

  Future<void> _openSettings() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await _repository.openSettings();
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.galleryLoadFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refreshPending = false;
        await _refresh();
      }
    }
  }

  Future<void> _selectRoles() async {
    if (_busy || _loading) return;
    final roles = await RoleSelectionSheet.show(
      context: context,
      selected: widget.selectedRoles,
    );
    if (mounted && roles != null) await _confirm(roles: roles);
  }

  Future<void> _selectAssets() async {
    if (_busy || _loading) return;
    final assets = await AssetSelectionSheet.show(
      context: context,
      selected: widget.selectedAssets,
      limit: widget.limit + widget.selectedAssets.length - _selected.length,
    );
    if (mounted && assets != null) await _confirm(assets: assets);
  }

  Future<void> _confirm({
    List<LibraryRole>? roles,
    List<LibraryWork>? assets,
  }) async {
    if ((_selected.isEmpty &&
            (roles?.isEmpty ?? true) &&
            (assets?.isEmpty ?? true)) ||
        _busy ||
        (_loading && _selected.isNotEmpty)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final files = <XFile>[];
      for (final photo in _selected.values.toList()) {
        final file = photo.file ?? await _repository.readPhoto(photo.gallery!);
        if (file == null) throw StateError('Photo no longer available');
        files.add(file);
      }
      if (mounted) {
        Navigator.pop(
          context,
          AttachmentPickerResult.selection(
            images: files,
            roles: roles,
            assets: assets,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context)!.imageReadFailed);
        _refreshPending = _usesLibrary;
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _flushRefresh();
      }
    }
  }

  Widget _sources(AppLocalizations l10n, ColorScheme colors) {
    final sources = [
      _SourceTile(
        key: const Key('attachment-source-gallery'),
        label: l10n.gallery,
        icon: AppSvgIcon.asset(
          'attachment_camera',
          size: 44,
          color: colors.onSurface,
        ),
        onTap: _busy ? null : _import,
      ),
      _SourceTile(
        key: const Key('attachment-source-files'),
        label: l10n.file,
        icon: AppSvgIcon.asset(
          'attachment_file',
          size: 44,
          color: colors.onSurface,
        ),
        onTap: _busy ? null : () => _import(fromFiles: true),
      ),
      _SourceTile(
        key: const Key('attachment-source-roles'),
        label: l10n.roles,
        icon: AppSvgIcon.asset(
          'attachment_role_upright',
          size: 44,
          color: colors.onSurface,
        ),
        onTap: _busy || _loading ? null : _selectRoles,
      ),
      _SourceTile(
        key: const Key('attachment-source-assets'),
        label: l10n.assets,
        icon: AppSvgIcon.asset(
          'attachment_asset',
          size: 44,
          color: colors.onSurface,
        ),
        onTap: _busy || _loading ? null : _selectAssets,
      ),
    ];
    if (MediaQuery.textScalerOf(context).scale(16) > 22) {
      return Column(
        key: const Key('attachment-sources'),
        spacing: 8,
        children: [
          Row(spacing: 8, children: sources.take(2).toList()),
          Row(spacing: 8, children: sources.skip(2).toList()),
        ],
      );
    }
    return Row(
      key: const Key('attachment-sources'),
      spacing: 8,
      children: sources,
    );
  }

  Widget _legalNotice(AppLocalizations l10n, ColorScheme colors, bool dark) =>
      LegalDocumentLinks(
        text: l10n.attachmentLegalNotice,
        userAgreementLabel: l10n.userAgreement,
        privacyPolicyLabel: l10n.privacyPolicy,
        style: TextStyle(
          fontSize: 14,
          height: 22 / 14,
          color: dark ? colors.onSurfaceVariant : const Color(0xFF999999),
        ),
        linkStyle: TextStyle(
          color: dark ? colors.onSurface : const Color(0xFF666666),
          decoration: TextDecoration.underline,
        ),
        openFailedMessage: l10n.webPageLoadFailed,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final photos = [..._imported, ..._photos];
    final accessDenied =
        _access == GalleryAccess.denied || _access == GalleryAccess.restricted;
    final selectedIds = _selected.keys.toList();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: ColoredBox(
          color: scheme.surface.withValues(alpha: .9),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scrollSources =
                  constraints.maxHeight < 600 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22;
              final scrollNotice =
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              return SizedBox(
                height: math.min(
                  MediaQuery.sizeOf(context).height * AppSheet.maxHeightFactor,
                  (constraints.maxWidth - 56) / 3 * 4 +
                      276 +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          l10n.attachmentTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!scrollSources) ...[
                          _sources(l10n, scheme),
                          const SizedBox(height: 20),
                        ],
                        Expanded(
                          child: CustomScrollView(
                            key: const Key('attachment-photo-scroll'),
                            controller: _scroll,
                            slivers: [
                              if (scrollSources) ...[
                                SliverToBoxAdapter(
                                  child: _sources(l10n, scheme),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 20),
                                ),
                              ],
                              if (_usesLibrary &&
                                  !_loading &&
                                  !_failed &&
                                  _access == GalleryAccess.denied)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextButton.icon(
                                      onPressed: _busy ? null : _openSettings,
                                      icon: const Icon(Icons.settings_outlined),
                                      label: Text(l10n.galleryOpenSettings),
                                    ),
                                  ),
                                ),
                              if (_loading)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                )
                              else if (_failed)
                                SliverToBoxAdapter(
                                  child: _GalleryStatus(
                                    message: l10n.galleryLoadFailed,
                                    action: l10n.retry,
                                    onTap: _refresh,
                                  ),
                                )
                              else if (accessDenied)
                                SliverToBoxAdapter(
                                  child: _GalleryStatus(
                                    message: _access == GalleryAccess.restricted
                                        ? l10n.galleryRestricted
                                        : l10n.galleryAccessDenied,
                                  ),
                                )
                              else if (_usesLibrary && photos.isEmpty)
                                SliverToBoxAdapter(
                                  child: _GalleryStatus(
                                    message: l10n.galleryEmpty,
                                  ),
                                ),
                              SliverGrid.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                    ),
                                itemCount: photos.length,
                                itemBuilder: (context, index) {
                                  final photo = photos[index];
                                  return _PhotoTile(
                                    key: ValueKey(photo.id),
                                    photo: photo,
                                    repository: _repository,
                                    selectedNumber:
                                        selectedIds.indexOf(photo.id) + 1,
                                    onTap: _busy || _loading
                                        ? null
                                        : () => _toggle(photo),
                                  );
                                },
                              ),
                              if (_moreLoading)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                              if (_pageFailed)
                                SliverToBoxAdapter(
                                  child: TextButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(l10n.retry),
                                  ),
                                ),
                              if (scrollNotice)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: _legalNotice(l10n, scheme, dark),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!scrollNotice) ...[
                          const SizedBox(height: 20),
                          _legalNotice(l10n, scheme, dark),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: math.max(
                            50,
                            MediaQuery.textScalerOf(context).scale(16) * 1.4 +
                                16,
                          ),
                          child: FilledButton(
                            key: const Key('attachment-confirm'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            onPressed: _selected.isEmpty || _busy || _loading
                                ? null
                                : _confirm,
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(l10n.attachmentConfirm),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Photo {
  _Photo.gallery(GalleryPhoto photo)
    : id = 'gallery:${photo.id}',
      name = photo.name,
      gallery = photo,
      file = null;
  _Photo.file(XFile value)
    : id = 'file:${value.path}:${value.name}',
      name = value.name,
      gallery = null,
      file = value;

  final String id;
  final String name;
  final GalleryPhoto? gallery;
  final XFile? file;
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: SizedBox(
      height: math.max(
        94,
        64 + MediaQuery.textScalerOf(context).scale(16) * 1.4,
      ),
      child: Material(
        color: AppColors.brand.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(dimension: 44, child: Center(child: icon)),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({
    required this.photo,
    required this.repository,
    required this.selectedNumber,
    required this.onTap,
    super.key,
  });
  final _Photo photo;
  final GalleryRepository repository;
  final int selectedNumber;
  final VoidCallback? onTap;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late final Future<Uint8List?> _thumbnail =
      widget.photo.file?.readAsBytes() ??
      widget.repository.thumbnail(widget.photo.gallery!);

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedNumber > 0;
    return Semantics(
      label: widget.photo.name,
      selected: selected,
      button: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: _thumbnail,
                builder: (context, snapshot) => snapshot.hasData
                    ? Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheWidth: 384,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      )
                    : Center(
                        child: Icon(
                          snapshot.hasError
                              ? Icons.broken_image_outlined
                              : Icons.photo_outlined,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.brand : Colors.white,
                    border: selected
                        ? null
                        : Border.all(color: const Color(0xFFEDEDED), width: 4),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const AppSvgIcon.asset('attachment_selected', size: 20)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryStatus extends StatelessWidget {
  const _GalleryStatus({required this.message, this.action, this.onTap});
  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.refresh),
            label: Text(action!),
          ),
      ],
    ),
  );
}
