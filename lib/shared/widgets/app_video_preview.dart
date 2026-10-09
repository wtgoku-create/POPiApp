import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/generated/app_localizations.dart';

/// Opens a full-screen player and releases playback when the route closes.
abstract final class AppVideoPreview {
  static Future<void> show({required BuildContext context, required Uri url}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => _VideoPreview(url: url)),
      );
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.url});

  final Uri url;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  double? _seekSeconds;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final previous = _controller;
    final controller = VideoPlayerController.networkUrl(widget.url);
    setState(() {
      _controller = controller;
      _loading = true;
      _failed = false;
      _seekSeconds = null;
    });
    try {
      await previous?.dispose();
      if (!mounted || generation != _generation) return;
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        await controller.play();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _command(
    Future<void> Function(VideoPlayerController) run,
  ) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await run(controller);
    } catch (_) {
      if (mounted && identical(controller, _controller)) {
        setState(() => _failed = true);
      }
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
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('asset-preview-video'),
        backgroundColor: Colors.black,
        body: SafeArea(
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final failed = _failed || value.hasError;
              final ready = !_loading && !failed && value.isInitialized;
              final total = value.duration.inMilliseconds / 1000;
              final seconds =
                  (_seekSeconds ?? value.position.inMilliseconds / 1000).clamp(
                    0.0,
                    total,
                  );
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        key: const Key('video-preview-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: failed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.videoLoadFailed,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                TextButton(
                                  key: const Key('video-preview-retry'),
                                  onPressed: _load,
                                  child: Text(l10n.retry),
                                ),
                              ],
                            )
                          : !ready
                          ? const CircularProgressIndicator(color: Colors.white)
                          : AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(controller),
                                  if (value.isBuffering)
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  if (ready)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            key: const Key('video-preview-seek'),
                            value: seconds,
                            max: total > 0 ? total : 1,
                            semanticFormatterCallback: (value) =>
                                '${l10n.videoSeek}: ${_time(Duration(seconds: value.toInt()))}',
                            onChanged: total > 0
                                ? (value) =>
                                      setState(() => _seekSeconds = value)
                                : null,
                            onChangeEnd: (value) async {
                              await _command(
                                (controller) => controller.seekTo(
                                  Duration(
                                    milliseconds: (value * 1000).round(),
                                  ),
                                ),
                              );
                              if (mounted) setState(() => _seekSeconds = null);
                            },
                          ),
                          Row(
                            children: [
                              IconButton(
                                key: const Key('video-preview-play'),
                                tooltip: value.isPlaying
                                    ? l10n.videoPause
                                    : l10n.videoPlay,
                                onPressed: () => _command((controller) async {
                                  if (value.isPlaying) {
                                    await controller.pause();
                                  } else {
                                    if (value.isCompleted) {
                                      await controller.seekTo(Duration.zero);
                                    }
                                    await controller.play();
                                  }
                                }),
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${_time(Duration(milliseconds: (seconds * 1000).round()))} / ${_time(value.duration)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                key: const Key('video-preview-mute'),
                                tooltip: value.volume == 0
                                    ? l10n.videoUnmute
                                    : l10n.videoMute,
                                onPressed: () => _command(
                                  (controller) => controller.setVolume(
                                    value.volume == 0 ? 1 : 0,
                                  ),
                                ),
                                icon: Icon(
                                  value.volume == 0
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
