import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/media_image_repository.dart';
import '../../core/network/network_api.dart';
import 'network_provider.dart';
import 'user_provider.dart';

final mediaImageRepositoryProvider = Provider(
  (ref) => MediaImageRepository(NetworkApi(ref.watch(dioProvider))),
);

// Share resolution across visible thumbnails and clear it when accounts change.
final mediaImageUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, url) {
    ref.watch(userProvider.select((user) => user?.id));
    final token = CancelToken();
    ref.onDispose(token.cancel);
    return ref
        .watch(mediaImageRepositoryProvider)
        .resolve(url, cancelToken: token);
  },
);
