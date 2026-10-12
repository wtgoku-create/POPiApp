import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../../../shared/widgets/app_video_preview.dart';
import '../../data/home_creation_repository.dart';

/// Resolves generated media; playback and controls use the shared video player.
class RoleGeneratedVideo extends StatefulWidget {
  const RoleGeneratedVideo({
    required this.mediaId,
    required this.repository,
    super.key,
  });

  final String mediaId;
  final HomeCreationRepository repository;

  @override
  State<RoleGeneratedVideo> createState() => _RoleGeneratedVideoState();
}

class _RoleGeneratedVideoState extends State<RoleGeneratedVideo> {
  CancelToken? _token;
  Uri? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RoleGeneratedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    _token?.cancel();
    final token = _token = CancelToken();
    setState(() {
      _url = null;
      _failed = false;
    });
    try {
      final url = await widget.repository.media(
        widget.mediaId,
        cancelToken: token,
      );
      if (mounted && !token.isCancelled) setState(() => _url = url);
    } catch (_) {
      if (mounted && !token.isCancelled) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Colors.black,
        child: url != null
            ? AppVideoPlayer(
                key: ObjectKey(_token),
                url: url,
                aspectRatio: 16 / 9,
                controlsKeyPrefix: 'role-video',
                onRetry: _load,
                onFullscreen: (url) =>
                    AppVideoPreview.show(context: context, url: url),
              )
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: _failed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.videoLoadFailed,
                              style: const TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              key: const Key('role-video-retry'),
                              onPressed: _load,
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
      ),
    );
  }
}
