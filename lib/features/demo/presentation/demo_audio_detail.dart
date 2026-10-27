import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme.dart';
import '../../../core/storage/gallery_video_storage.dart';
import '../../../core/storage/sensitive_media_headers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/harness_access_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_video_player_source.dart';
import '../data/demo_media_exporter.dart';
import '../domain/demo_models.dart';

/// Audio detail panel matching the Figma file information and waveform layout.
class DemoAudioDetail extends StatefulWidget {
  const DemoAudioDetail({required this.asset, this.readBytes, super.key});
  final DemoAsset asset;
  final Future<Uint8List> Function()? readBytes;

  @override
  State<DemoAudioDetail> createState() => _DemoAudioDetailState();
}

class _DemoAudioDetailState extends State<DemoAudioDetail>
    with WidgetsBindingObserver {
  VideoPlayerController? _player;
  late final ValueNotifier<VideoPlayerValue> _placeholder;
  CancelToken? _downloadToken;
  String? _downloadedPath;
  ProviderContainer? _accessContainer;
  ProviderSubscription<String?>? _accessSubscription;
  int _generation = 0;
  int? _bytes;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placeholder = ValueNotifier(
      VideoPlayerValue(duration: _metadataDuration(Duration.zero)),
    );
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.asset.isRemote) return;
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      // Isolated widget tests may not use Riverpod.
    }
    if (identical(container, _accessContainer)) return;
    _accessSubscription?.close();
    _accessContainer = container;
    if (container == null) return;
    _accessSubscription = container.listen<String?>(
      harnessAccessCacheKeyProvider(widget.asset.contentUrl),
      (previous, next) {
        if (previous != next && mounted) _initialize();
      },
    );
  }

  Map<String, String> _accessHeaders() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessHeadersProvider(widget.asset.contentUrl));
    } on StateError {
      return const {};
    }
  }

  VoidCallback? _onUnauthorized() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessUnauthorizedProvider(widget.asset.contentUrl));
    } on StateError {
      return null;
    }
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    _downloadToken?.cancel();
    if (!_loading) setState(() => _loading = true);
    final previous = _player;
    final previousPath = _downloadedPath;
    _player = null;
    _downloadedPath = null;
    try {
      final bytes = await DemoMediaExporter.size(
        widget.asset,
        readBytes: widget.readBytes,
      );
      await previous?.dispose();
      if (previousPath != null) {
        await GalleryVideoStorage.deleteDownloaded(previousPath);
      }
      if (!mounted || generation != _generation) return;
      late final VideoPlayerController player;
      if (!widget.asset.isRemote) {
        player = VideoPlayerController.asset(widget.asset.media);
      } else {
        final headers = _accessHeaders();
        if (!kIsWeb && hasSensitiveMediaHeaders(headers)) {
          final token = _downloadToken = CancelToken();
          final path = await GalleryVideoStorage.downloadForPlayback(
            Uri.parse(widget.asset.contentUrl),
            cancelToken: token,
            headers: headers,
            onUnauthorized: _onUnauthorized(),
            fileExtension: DemoMediaExporter.displayExtension(widget.asset),
          );
          if (!mounted || generation != _generation || token.isCancelled) {
            await GalleryVideoStorage.deleteDownloaded(path);
            return;
          }
          _downloadedPath = path;
          player = appVideoPlayerFile(path);
        } else {
          player = VideoPlayerController.networkUrl(
            Uri.parse(widget.asset.contentUrl),
            httpHeaders: headers,
          );
        }
      }
      _player = player;
      if (mounted) setState(() {});
      await player.initialize();
      if (mounted && generation == _generation) {
        setState(() => _bytes = bytes);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        AppToast.error(context, AppLocalizations.of(context)!.demoStorageError);
      }
    } finally {
      if (generation == _generation) {
        _downloadToken = null;
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _command(
    Future<void> Function(VideoPlayerController player) action,
  ) async {
    final player = _player;
    if (player == null) return;
    try {
      await action(player);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context)!.demoStorageError);
      }
    }
  }

  void _seek(Duration position) => _command(
    (player) => player.seekTo(
      Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          player.value.duration.inMilliseconds,
        ),
      ),
    ),
  );

  Future<void> _save() async {
    final box = context.findRenderObject()! as RenderBox;
    setState(() => _saving = true);
    try {
      final saved = await DemoMediaExporter.save(
        widget.asset,
        box.localToGlobal(Offset.zero) & box.size,
        readBytes: widget.readBytes,
      );
      if (mounted && saved) {
        AppToast.success(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaved,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.sessionArtifactSaveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _command((player) => player.pause());
    }
  }

  @override
  void dispose() {
    _generation++;
    _downloadToken?.cancel();
    _accessSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    _placeholder.dispose();
    final player = _player;
    final path = _downloadedPath;
    if (player != null) {
      unawaited(() async {
        await player.dispose();
        if (path != null) await GalleryVideoStorage.deleteDownloaded(path);
      }());
    } else if (path != null) {
      unawaited(GalleryVideoStorage.deleteDownloaded(path));
    }
    super.dispose();
  }

  String _time(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  Duration _metadataDuration(Duration playerDuration) {
    if (!widget.asset.isRemote || widget.asset.durationSeconds <= 0) {
      return playerDuration;
    }
    return Duration(
      milliseconds: (widget.asset.durationSeconds * 1000).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, size: 26),
                  ),
                  Expanded(
                    child: Text(
                      l.sessionArtifactAudioDetail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.download,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.brand,
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const AppSvgIcon.asset(
                            'session_artifact_download',
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _player ?? _placeholder,
                builder: (context, value, _) {
                  final ready = value.isInitialized && !value.hasError;
                  return ListView(
                    children: [
                      Text(
                        widget.asset.title,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 25 / 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          DemoMediaExporter.displayExtension(
                            widget.asset,
                          ).toUpperCase(),
                          _time(_metadataDuration(value.duration)),
                          if (_bytes != null)
                            '${(_bytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: colors.onSurfaceVariant.withValues(alpha: .65),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        key: const Key('demo-audio-player'),
                        height: 208,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 48,
                              child: !_loading
                                  ? _AudioWaveform(
                                      position: value.position,
                                      duration: value.duration,
                                      onSeek: _seek,
                                    )
                                  : const Center(
                                      child: SizedBox.square(
                                        dimension: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _time(value.position),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    color: AppColors.brand,
                                  ),
                                ),
                                Text(
                                  _time(value.duration),
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: .65,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 56,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    key: const Key('demo-audio-backward'),
                                    tooltip: l.demoAudioBackward,
                                    onPressed: ready
                                        ? () => _seek(
                                            value.position -
                                                const Duration(seconds: 15),
                                          )
                                        : null,
                                    icon: const _SeekIcon(backward: true),
                                  ),
                                  const SizedBox(width: 17),
                                  IconButton(
                                    key: const Key('demo-audio-play'),
                                    tooltip: value.isPlaying
                                        ? l.demoPause
                                        : l.demoPlayback,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.brand
                                          .withValues(alpha: .2),
                                    ),
                                    onPressed: !ready
                                        ? (_loading ? null : _initialize)
                                        : () => _command((player) async {
                                            if (value.isPlaying) {
                                              await player.pause();
                                            } else {
                                              if (value.position >=
                                                  value.duration) {
                                                await player.seekTo(
                                                  Duration.zero,
                                                );
                                              }
                                              await player.play();
                                            }
                                          }),
                                    icon: value.isPlaying
                                        ? const AppSvgIcon.asset(
                                            'audio_pause',
                                            size: 20,
                                          )
                                        : const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(width: 17),
                                  IconButton(
                                    key: const Key('demo-audio-forward'),
                                    tooltip: l.demoAudioForward,
                                    onPressed: ready
                                        ? () => _seek(
                                            value.position +
                                                const Duration(seconds: 15),
                                          )
                                        : null,
                                    icon: const _SeekIcon(backward: false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.demoGenerated,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _SeekIcon extends StatelessWidget {
  const _SeekIcon({required this.backward});
  final bool backward;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      AppSvgIcon.asset(
        backward ? 'audio_seek_backward' : 'audio_seek_forward',
        size: 26,
      ),
      const Text(
        '15',
        style: TextStyle(fontSize: 10, height: 1.4, color: AppColors.brand),
      ),
    ],
  );
}

class _AudioWaveform extends StatelessWidget {
  const _AudioWaveform({
    required this.position,
    required this.duration,
    required this.onSeek,
  });
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  static const _heights = [
    9.6,
    18.24,
    30.24,
    21.6,
    38.4,
    26.4,
    44.16,
    33.12,
    19.2,
    34.56,
    48.0,
    27.84,
    14.4,
    24.96,
    40.8,
    31.2,
    17.28,
    27.36,
    45.12,
    21.12,
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = (constraints.maxWidth / 7).floor().clamp(1, 52);
      final progress = duration.inMilliseconds == 0
          ? 0.0
          : position.inMilliseconds / duration.inMilliseconds;
      return Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    width: 3,
                    height: _heights[i % _heights.length],
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(
                        alpha: i / count < progress ? 1 : .18,
                      ),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              thumbShape: SliderComponentShape.noThumb,
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              key: const Key('demo-audio-seek'),
              label: AppLocalizations.of(context)!.demoSeek,
              value: progress.clamp(0, 1),
              onChanged: (value) => onSeek(
                Duration(
                  milliseconds: (duration.inMilliseconds * value).round(),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
