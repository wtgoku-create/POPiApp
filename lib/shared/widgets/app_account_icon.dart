import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_svg_icon.dart';

/// Account icons share the server color while retaining their existing glyphs.
class AppAccountIcon extends StatelessWidget {
  const AppAccountIcon({
    this.backgroundColor,
    this.assetName = 'ip_guide_account',
    this.size = 50,
    super.key,
  });

  final String? backgroundColor;
  final String assetName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hex = backgroundColor?.trim() ?? '';
    final color = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
        ? Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))
        : null;
    final icon = AppSvgIcon.asset(
      assetName,
      size: size,
      colorMapper: color == null ? null : const _TransparentBackgroundMapper(),
    );
    return SizedBox.square(
      dimension: size,
      child: color == null
          ? icon
          : DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size / 5),
              ),
              child: icon,
            ),
    );
  }
}

// The source SVG background has its own opacity; paint the server color outside it.
class _TransparentBackgroundMapper extends ColorMapper {
  const _TransparentBackgroundMapper();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => elementName == 'rect' && attributeName == 'fill'
      ? Colors.transparent
      : color;
}
