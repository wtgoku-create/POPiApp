import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/harness_access_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../data/demo_repository.dart';

/// 角色图片走 Agent 的鉴权代理，业务 token 不发往 CDN。
class DemoRoleImage extends ConsumerWidget {
  const DemoRoleImage({
    required this.repository,
    required this.source,
    this.width,
    this.height,
    this.fit,
    this.loadingBuilder,
    this.errorBuilder,
    super.key,
  });
  final DemoRepository repository;
  final String source;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = repository.roleImageUrl(source);
    final headers = ref.watch(harnessAccessHeadersProvider(url));
    return AppNetworkImage(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      headers: headers,
      cacheKey: headers.isEmpty
          ? null
          : ref.watch(harnessAccessCacheKeyProvider(url)),
      onUnauthorized: headers.isEmpty
          ? null
          : ref.watch(harnessAccessUnauthorizedProvider(url)),
    );
  }
}

/// 全屏预览与列表图片使用同一用户的访问凭据与缓存命名空间。
ImageProvider roleImageProvider(
  BuildContext context,
  DemoRepository repository,
  String source,
) {
  final url = repository.roleImageUrl(source);
  final container = ProviderScope.containerOf(context, listen: false);
  final headers = container.read(harnessAccessHeadersProvider(url));
  return AppImageCache.provider(
    url,
    headers: headers,
    cacheKey: headers.isEmpty
        ? null
        : container.read(harnessAccessCacheKeyProvider(url)),
    onUnauthorized: headers.isEmpty
        ? null
        : container.read(harnessAccessUnauthorizedProvider(url)),
  );
}
