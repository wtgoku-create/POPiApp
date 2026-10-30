import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/demo_models.dart';

/// Figma's square document/audio cover, shared by grid and list assets.
class DemoDocumentCover extends StatelessWidget {
  const DemoDocumentCover({required this.kind, this.format = '', super.key});
  final DemoAssetKind kind;
  final String format;
  static const _waveHeights = [
    8.0,
    13.0,
    23.0,
    17.0,
    29.0,
    19.0,
    33.0,
    25.0,
    15.0,
    25.0,
    36.0,
    21.0,
    11.0,
    19.0,
    31.0,
    23.0,
    13.0,
    21.0,
    33.0,
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: ValueKey('demo-document-cover-${kind.name}'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const RadialGradient(
        colors: [
          Color(0x1AEAE4FF),
          Color(0x1ACBBCFD),
          Color(0x1AAC95FA),
          Color(0x1A8E6EF8),
          Color(0x1A6F47F5),
        ],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final extent = math.min(constraints.maxWidth, constraints.maxHeight);
        if (kind == DemoAssetKind.script) {
          final label = format.trim().toUpperCase();
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppSvgIcon.asset(
                  'demo_script_cover',
                  size: math.min(50, extent * .5),
                ),
                if (label.isNotEmpty)
                  Positioned(
                    bottom: extent * .16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: ShapeDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            FractionallySizedBox(
              widthFactor: .7,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 129,
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final height in _waveHeights)
                        Container(
                          width: 3,
                          height: height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AppSvgIcon.asset('demo_play', size: math.min(40, extent * .4)),
          ],
        );
      },
    ),
  );
}
