import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/demo_media_exporter.dart';
import '../domain/demo_models.dart';

/// Audio detail panel matching the Figma file information and waveform layout.
class DemoAudioDetail extends StatefulWidget {
  const DemoAudioDetail({required this.asset, super.key});
  final DemoAsset asset;

  @override
  State<DemoAudioDetail> createState() => _DemoAudioDetailState();
}

class _DemoAudioDetailState extends State<DemoAudioDetail>
    with WidgetsBindingObserver {
  late final _player = VideoPlayerController.asset(widget.asset.media);
  int? _bytes;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final bytes = await DemoMediaExporter.size(widget.asset);
      if (!mounted) return;
      await _player.initialize();
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context)!.demoStorageError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _command(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        AppToast.error(context, AppLocalizations.of(context)!.demoStorageError);
      }
    }
  }

  void _seek(Duration position) => _command(
    () => _player.seekTo(
      Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          _player.value.duration.inMilliseconds,
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
    if (state != AppLifecycleState.resumed) _command(_player.pause);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  String _time(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 20),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _player,
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
                          widget.asset.media.split('.').last.toUpperCase(),
                          _time(value.duration),
                          if (_bytes != null)
                            '${(_bytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: colors.onSurfaceVariant.withValues(alpha: .65),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        key: const Key('demo-audio-player'),
                        height: 244,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 50,
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
                            const SizedBox(height: 10),
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
                            const SizedBox(height: 10),
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
                                        : () => _command(() async {
                                            if (value.isPlaying) {
                                              await _player.pause();
                                            } else {
                                              if (value.position >=
                                                  value.duration) {
                                                await _player.seekTo(
                                                  Duration.zero,
                                                );
                                              }
                                              await _player.play();
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
