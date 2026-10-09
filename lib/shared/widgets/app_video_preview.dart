import 'package:flutter/material.dart';

import 'app_media_preview.dart';

/// Opens a video in the shared media preview page.
abstract final class AppVideoPreview {
  static Future<void> show({required BuildContext context, required Uri url}) =>
      AppMediaPreview.showVideo(context: context, url: url);
}
