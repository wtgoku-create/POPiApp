import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/providers/harness_access_provider.dart';
import '../../role_guide/presentation/widgets/role_guide_controls.dart';
import '../domain/library_work.dart';

/// Shared image/video preview for library selection and composer attachments.
class LibraryWorkThumbnail extends StatefulWidget {
  const LibraryWorkThumbnail({required this.work, super.key});

  final LibraryWork work;

  @override
  State<LibraryWorkThumbnail> createState() => _LibraryWorkThumbnailState();
}

class _LibraryWorkThumbnailState extends State<LibraryWorkThumbnail> {
  bool _useFallback = false;
  bool _fallbackScheduled = false;

  LibraryWork get work => widget.work;

  @override
  void didUpdateWidget(LibraryWorkThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.id != work.id ||
        oldWidget.work.previewUrl != work.previewUrl ||
        _fallbackFor(oldWidget.work) != _fallbackFor(work)) {
      _useFallback = false;
      _fallbackScheduled = false;
    }
  }

  String? get _fallbackUrl => _fallbackFor(work);

  void _fallbackToOriginal(Object error) {
    if (_useFallback ||
        _fallbackScheduled ||
        _fallbackUrl == null ||
        error is HttpExceptionWithStatus && error.statusCode == 401) {
      return;
    }
    _fallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _useFallback = true;
        _fallbackScheduled = false;
      });
    });
  }

  Widget _image(BuildContext context, String url) {
    if (url.isEmpty) return _error(context);
    if (url.startsWith('assets/')) {
      return _render(context, AssetImage(url));
    }
    if (!_isOwnedHarnessMedia(url) || !_hasProviderScope(context)) {
      return _render(context, AppImageCache.provider(url));
    }
    return Consumer(
      builder: (context, ref, _) => _render(
        context,
        AppImageCache.provider(
          url,
          headers: ref.watch(harnessAccessHeadersProvider(url)),
          cacheKey: ref.watch(harnessAccessCacheKeyProvider(url)),
          onUnauthorized: ref.watch(harnessAccessUnauthorizedProvider(url)),
        ),
      ),
    );
  }

  Widget _render(BuildContext context, ImageProvider provider) => Image(
    image: provider,
    fit: BoxFit.cover,
    errorBuilder: (context, error, _) {
      _fallbackToOriginal(error);
      return _error(context);
    },
  );

  Widget _error(BuildContext context) => ColoredBox(
    color: roleGuideTint(context),
    child: const Icon(Icons.broken_image_outlined),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      fit: StackFit.expand,
      children: [
        _image(context, _useFallback ? _fallbackUrl! : work.previewUrl),
        if (work.isVideo)
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
          ),
      ],
    ),
  );
}

String? _fallbackFor(LibraryWork work) {
  if (work.isVideo || work.imageUrls.isEmpty) return null;
  final url = work.imageUrls.first;
  return url.isEmpty || url == work.previewUrl ? null : url;
}

bool _hasProviderScope(BuildContext context) {
  try {
    ProviderScope.containerOf(context, listen: false);
    return true;
  } on StateError {
    return false;
  }
}

bool _isOwnedHarnessMedia(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      RegExp(
        r'^/api_agent/v2/assets/[A-Za-z0-9_-]+/(?:content|poster|thumbnail)$',
      ).hasMatch(uri.path) &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
