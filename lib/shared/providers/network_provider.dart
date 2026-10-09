import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/config/app_config.dart';
import 'storage_provider.dart';

final dioProvider = Provider<Dio>(
  (ref) => DioClient(secureStorage: ref.watch(secureStorageProvider)).dio,
);

/// Native Bearer clients may omit Origin; configured origins must be allowed by Agent.
final agentDioProvider = Provider<Dio>(
  (ref) => DioClient(
    secureStorage: ref.watch(secureStorageProvider),
    baseUrl: AppConfig.agentApiBaseUrl,
    headers: {
      if (AppConfig.agentApiOrigin.isNotEmpty)
        'Origin': AppConfig.agentApiOrigin,
    },
  ).dio,
);
