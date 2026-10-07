import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Pulses a placeholder layout while respecting the system motion setting.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final _opacity = _controller
      .drive(CurveTween(curve: Curves.easeInOut))
      .drive(Tween<double>(begin: .45, end: 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: FadeTransition(opacity: _opacity, child: widget.child),
    ),
  );
}

/// A theme-aware placeholder for text, thumbnails, or avatars.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    this.width,
    this.height,
    this.radius = AppRadii.small,
    super.key,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(
          alpha: colors.brightness == Brightness.dark ? .12 : .08,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder rows matching a library's avatar and two lines of text.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({required this.label, this.itemCount = 5, super.key});

  final String label;
  final int itemCount;

  @override
  Widget build(BuildContext context) => AppSkeleton(
    label: label,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < itemCount; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
              child: Row(
                children: [
                  const AppSkeletonBox(width: 70, height: 70, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: index.isEven ? .65 : .45,
                          child: const AppSkeletonBox(height: 18),
                        ),
                        const SizedBox(height: 10),
                        const FractionallySizedBox(
                          widthFactor: .85,
                          child: AppSkeletonBox(height: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Square placeholders matching the asset library's thumbnail grid.
class AppSkeletonGrid extends StatelessWidget {
  const AppSkeletonGrid({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => AppSkeleton(
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSkeletonBox(width: 110, height: 16),
        const SizedBox(height: 8),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (_, _) => const AppSkeletonBox(radius: 16),
        ),
      ],
    ),
  );
}
