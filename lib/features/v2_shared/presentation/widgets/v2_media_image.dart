import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_authenticated_image.dart';
import '../../../../shared/widgets/app_skeleton.dart';

ImageProvider v2ImageProvider(
  String source, {
  Map<String, String> headers = const {},
}) => source.startsWith('https://') || source.startsWith('http://')
    ? AppAuthenticatedImage(source, headers: headers)
    : AssetImage(source);

class V2MediaImage extends StatelessWidget {
  const V2MediaImage(
    this.source, {
    this.headers = const {},
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    super.key,
  });
  final String source;
  final Map<String, String> headers;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  @override
  Widget build(BuildContext context) {
    Widget placeholder() => SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: const Center(child: Icon(Icons.image_outlined)),
      ),
    );
    if (source.isEmpty) return placeholder();
    return Image(
      image: v2ImageProvider(source, headers: headers),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      frameBuilder: (context, child, frame, synchronous) =>
          frame != null || synchronous
          ? child
          : AppSkeletonBox(width: width, height: height),
      errorBuilder: (_, _, _) => placeholder(),
    );
  }
}
