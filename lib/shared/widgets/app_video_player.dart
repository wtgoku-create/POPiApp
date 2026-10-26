import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../core/storage/gallery_video_storage.dart';
import '../../core/storage/sensitive_media_headers.dart';
import '../providers/harness_access_provider.dart';
import 'app_video_player_source.dart';

/// Shared video surface, controls and playback lifecycle for inline and preview use.
class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({
    required this.url,
    this.autoplay = false,
    this.aspectRatio,
    this.onRetry,
    this.onFullscreen,
    this.controlsKeyPrefix = 'video-player',
    this.httpHeaders = const {},
    this.placeholder,
    super.key,
  });

  final Uri url;
  final bool autoplay;
  final double? aspectRatio;
  final VoidCallback? onRetry;
  final Future<void> Function(Uri)? onFullscreen;
  final String controlsKeyPrefix;
  final Map<String, String> httpHeaders;
  final ImageProvider? placeholder;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  double? _seekSeconds;
  int _generation = 0;
  Timer? _controlsTimer;
  bool _controlsVisible = true;
  bool _wasPlaying = false;
  bool _wasBuffering = false;
  CancelToken? _downloadToken;
  String? _downloadedPath;
  ProviderContainer? _accessContainer;
  ProviderSubscription<String?>? _accessSubscription;
  String? _subscribedUrl;

  Key _key(String suffix) => Key('${widget.controlsKeyPrefix}-$suffix');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToAccess();
  }

  @override
  void didUpdateWidget(AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !mapEquals(oldWidget.httpHeaders, widget.httpHeaders)) {
      _subscribeToAccess(force: true);
      _load();
    }
  }

  void _subscribeToAccess({bool force = false}) {
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      // Isolated widget tests and reusable embeds may not use Riverpod.
    }
    final url = widget.url.toString();
    if (!force &&
        identical(container, _accessContainer) &&
        url == _subscribedUrl) {
      return;
    }
    _accessSubscription?.close();
    _accessSubscription = null;
    _accessContainer = container;
    _subscribedUrl = url;
    if (container == null || widget.url.scheme == 'asset') return;
    _accessSubscription = container.listen<String?>(
      harnessAccessCacheKeyProvider(url),
      (previous, next) {
        if (previous != next && mounted) unawaited(_load());
      },
    );
  }

  Map<String, String> _resolvedHeaders() {
    if (widget.httpHeaders.isNotEmpty) return widget.httpHeaders;
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessHeadersProvider(widget.url.toString()));
    } on StateError {
      // Isolated widget tests and reusable embeds may not use Riverpod.
      return const {};
    }
  }

  VoidCallback? _resolvedUnauthorized() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessUnauthorizedProvider(widget.url.toString()));
    } on StateError {
      return null;
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _downloadToken?.cancel();
    final previous = _controller;
    final previousPath = _downloadedPath;
    _controller = null;
    _downloadedPath = null;
    previous?.removeListener(_syncControls);
    _controlsTimer?.cancel();
    setState(() {
      _loading = true;
      _failed = false;
      _seekSeconds = null;
      _controlsVisible = true;
      _wasPlaying = false;
      _wasBuffering = false;
    });
    try {
      await previous?.dispose();
      if (previousPath != null) {
        await GalleryVideoStorage.deleteDownloaded(previousPath);
      }
      if (!mounted || generation != _generation) return;
      late final VideoPlayerController controller;
      if (widget.url.scheme == 'asset') {
        controller = VideoPlayerController.asset(widget.url.path);
      } else {
        final headers = _resolvedHeaders();
        if (!kIsWeb && hasSensitiveMediaHeaders(headers)) {
          final token = _downloadToken = CancelToken();
          final path = await GalleryVideoStorage.downloadForPlayback(
            widget.url,
            cancelToken: token,
            headers: headers,
            onUnauthorized: _resolvedUnauthorized(),
          );
          if (!mounted || generation != _generation || token.isCancelled) {
            await GalleryVideoStorage.deleteDownloaded(path);
            return;
          }
          _downloadedPath = path;
          controller = appVideoPlayerFile(path);
        } else {
          controller = VideoPlayerController.networkUrl(
            widget.url,
            httpHeaders: headers,
          );
        }
      }
      controller.addListener(_syncControls);
      if (!mounted || generation != _generation) {
        controller.removeListener(_syncControls);
        await controller.dispose();
        final path = _downloadedPath;
        _downloadedPath = null;
        if (path != null) await GalleryVideoStorage.deleteDownloaded(path);
        return;
      }
      setState(() => _controller = controller);
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (widget.autoplay &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        await controller.play();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } finally {
      if (generation == _generation) _downloadToken = null;
    }
  }

  Future<void> _command(
    Future<void> Function(VideoPlayerController) action,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await action(controller);
    } catch (_) {
      if (mounted && identical(controller, _controller)) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _togglePlayback() => _command((controller) async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.isCompleted) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  });

  void _syncControls() {
    final value = _controller!.value;
    final playing = value.isPlaying && !value.isCompleted && !value.hasError;
    if (!mounted ||
        (playing == _wasPlaying && value.isBuffering == _wasBuffering)) {
      return;
    }
    _wasPlaying = playing;
    _wasBuffering = value.isBuffering;
    _showControls();
  }

  void _scheduleHide() {
    _controlsTimer?.cancel();
    final value = _controller?.value;
    if (value == null ||
        !value.isPlaying ||
        value.isBuffering ||
        value.isCompleted ||
        _seekSeconds != null) {
      return;
    }
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controller?.value.isPlaying != true) {
      _togglePlayback();
    } else if (_controlsVisible) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _command((controller) => controller.pause());
    }
  }

  @override
  void dispose() {
    _generation++;
    _downloadToken?.cancel();
    _accessSubscription?.close();
    _controlsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_syncControls);
      final path = _downloadedPath;
      unawaited(() async {
        await controller.dispose();
        if (path != null) await GalleryVideoStorage.deleteDownloaded(path);
      }());
    } else if (_downloadedPath case final path?) {
      unawaited(GalleryVideoStorage.deleteDownloaded(path));
    }
    super.dispose();
  }

  String _time(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _loadingSurface() => Stack(
    fit: StackFit.expand,
    children: [
      if (widget.placeholder case final image?)
        Image(
          key: _key('placeholder'),
          image: image,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      const Center(child: CircularProgressIndicator(color: Colors.white)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      final l10n = AppLocalizations.of(context)!;
      return AspectRatio(
        aspectRatio: widget.aspectRatio ?? 16 / 9,
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
                      key: _key('retry'),
                      onPressed: widget.onRetry ?? _load,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              )
            : _loadingSurface(),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final l10n = AppLocalizations.of(context)!;
        final failed = _failed || value.hasError;
        final ready = !_loading && !failed && value.isInitialized;
        final showControls = _controlsVisible || !value.isPlaying;
        final total = value.duration.inMilliseconds / 1000;
        final seconds = (_seekSeconds ?? value.position.inMilliseconds / 1000)
            .clamp(0.0, total);
        return AspectRatio(
          aspectRatio:
              widget.aspectRatio ?? (ready ? value.aspectRatio : 16 / 9),
          child: failed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.videoLoadFailed,
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        key: _key('retry'),
                        onPressed: widget.onRetry ?? _load,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : !ready
              ? _loadingSurface()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      button: true,
                      label: value.isPlaying ? l10n.videoPause : l10n.videoPlay,
                      onTap: _togglePlayback,
                      child: MouseRegion(
                        onHover: (_) => _showControls(),
                        child: GestureDetector(
                          key: _key('surface'),
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: _toggleControls,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showControls && !value.isBuffering)
                      Center(
                        child: SizedBox.square(
                          dimension: 64,
                          child: IconButton(
                            key: _key('play'),
                            tooltip: value.isPlaying
                                ? l10n.videoPause
                                : l10n.videoPlay,
                            iconSize: 48,
                            onPressed: _togglePlayback,
                            icon: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 4, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (value.isBuffering)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    if (showControls)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: _controls(context, value, seconds, total),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _controls(
    BuildContext context,
    VideoPlayerValue value,
    double seconds,
    double total,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final elapsed = _time(Duration(milliseconds: (seconds * 1000).round()));
    final timeLabel = '$elapsed / ${_time(value.duration)}';
    return SizedBox(
      key: _key('controls'),
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Tooltip(
              message: timeLabel,
              child: Text(
                constraints.maxWidth < 280 ? elapsed : timeLabel,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: .3),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: .12),
                  trackHeight: 3,
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Slider(
                  key: _key('seek'),
                  value: seconds,
                  max: total > 0 ? total : 1,
                  semanticFormatterCallback: (seconds) =>
                      '${l10n.videoSeek}: ${_time(Duration(seconds: seconds.toInt()))}',
                  onChangeStart: (seconds) {
                    _controlsTimer?.cancel();
                    setState(() => _seekSeconds = seconds);
                  },
                  onChanged: total > 0
                      ? (seconds) => setState(() => _seekSeconds = seconds)
                      : null,
                  onChangeEnd: (seconds) async {
                    final controller = _controller;
                    await _command(
                      (controller) => controller.seekTo(
                        Duration(milliseconds: (seconds * 1000).round()),
                      ),
                    );
                    if (mounted && identical(controller, _controller)) {
                      setState(() => _seekSeconds = null);
                      _scheduleHide();
                    }
                  },
                ),
              ),
            ),
            IconButton(
              key: _key('mute'),
              tooltip: value.volume == 0 ? l10n.videoUnmute : l10n.videoMute,
              onPressed: () {
                _showControls();
                _command(
                  (controller) =>
                      controller.setVolume(value.volume == 0 ? 1 : 0),
                );
              },
              icon: Icon(
                value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
            if (widget.onFullscreen != null)
              IconButton(
                key: _key('fullscreen'),
                tooltip: l10n.videoFullscreen,
                onPressed: () async {
                  final url = widget.url;
                  final generation = _generation;
                  await _command((controller) => controller.pause());
                  if (mounted && generation == _generation) {
                    await widget.onFullscreen?.call(url);
                  }
                },
                icon: const Icon(Icons.fullscreen, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
