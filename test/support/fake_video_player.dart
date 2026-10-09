import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayer extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final positions = <int, Duration>{};
  bool autoInitialize = true;
  bool failNext = false;
  bool playing = false;
  double volume = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length + 1;
    sources.add(options.dataSource);
    streams[id] = StreamController<VideoEvent>();
    if (failNext) {
      failNext = false;
      streams[id]!.addError(
        PlatformException(code: 'VideoError', message: 'Unable to load video'),
      );
    } else if (autoInitialize) {
      initialize(id);
    }
    return id;
  }

  void initialize(int id) => streams[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 60),
      size: const Size(1920, 1080),
    ),
  );

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing = false;
    await streams.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => playing = true;

  @override
  Future<void> pause(int playerId) async => playing = false;

  @override
  Future<void> setVolume(int playerId, double value) async => volume = value;

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      positions[playerId] = position;

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand(key: Key('native-video-surface'));
}
