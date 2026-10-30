import 'package:video_player/video_player.dart';

import 'app_video_player_source_stub.dart'
    if (dart.library.io) 'app_video_player_source_io.dart'
    as platform;

VideoPlayerController appVideoPlayerFile(String path) =>
    platform.appVideoPlayerFile(path);
