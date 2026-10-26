import 'dart:io';

import 'package:video_player/video_player.dart';

VideoPlayerController appVideoPlayerFile(String path) =>
    VideoPlayerController.file(File(path));
