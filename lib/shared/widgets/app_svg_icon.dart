import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon.asset(
    String name, {
    this.size,
    this.color,
    this.colorMapper,
    this.semanticsLabel,
    super.key,
  })  : assetName = name,
        url = null;

  const AppSvgIcon.network(
    String imageUrl, {
    this.size,
    this.color,
    this.colorMapper,
    this.semanticsLabel,
    super.key,
  })  : assetName = null,
        url = imageUrl;

  final String? assetName;
  final String? url;
  final double? size;
  final Color? color;
  final ColorMapper? colorMapper;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colorFilter =
        color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn);

    if (assetName != null) {
      return SvgPicture.asset(
        'assets/icons/$assetName.svg',
        width: size,
        height: size,
        colorFilter: colorFilter,
        colorMapper: colorMapper,
        semanticsLabel: semanticsLabel,
      );
    }

    return SvgPicture.network(
      url!,
      width: size,
      height: size,
      colorFilter: colorFilter,
      colorMapper: colorMapper,
      semanticsLabel: semanticsLabel,
    );
  }
}
