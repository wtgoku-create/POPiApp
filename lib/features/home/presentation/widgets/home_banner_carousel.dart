import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Swipeable Figma artwork with adjacent previews and page indicators.
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key});

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final _controller = PageController(
    initialPage: 1,
    viewportFraction: 284 / 440,
  );
  int _page = 1;

  static const _images = [
    'assets/images/home_banner_sunset.png',
    'assets/images/home_banner_aurora.png',
    'assets/images/home_banner_sunset.png',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(162.0, constraints.maxWidth * 162 / 440);
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                key: const Key('home-banner-carousel'),
                controller: _controller,
                itemCount: _images.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final page =
                        _controller.hasClients &&
                            _controller.position.hasContentDimensions
                        ? _controller.page ?? 1
                        : 1.0;
                    final distance = (page - index).abs().clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Transform.scale(
                        scale: 1 - distance * .2,
                        alignment: index < page
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Opacity(
                          opacity: 1 - distance * .5,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      _images[index],
                      key: Key('home-banner-image-$index'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: height,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _images.length; i++)
                    Semantics(
                      label: l10n.homeBannerPage(i + 1, _images.length),
                      selected: _page == i,
                      button: true,
                      child: GestureDetector(
                        key: Key('home-banner-dot-$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (MediaQuery.disableAnimationsOf(context)) {
                            _controller.jumpToPage(i);
                          } else {
                            _controller.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: SizedBox(
                          width: _page == i ? 19 : 11,
                          height: 25,
                          child: Center(
                            child: Container(
                              width: _page == i ? 15 : 7,
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                                color: AppColors.brand.withValues(
                                  alpha: _page == i ? 1 : .2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
