import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/teaching.dart';

class TeachingBanners extends StatefulWidget {
  const TeachingBanners({
    required this.highlights,
    required this.onMembership,
    this.onCommunity,
    super.key,
  });

  final TeachingHighlights highlights;
  final VoidCallback onMembership;
  final VoidCallback? onCommunity;

  @override
  State<TeachingBanners> createState() => _TeachingBannersState();
}

class _TeachingBannersState extends State<TeachingBanners> {
  PageController? _controller;
  double? _width;
  int _selected = 1;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = math.min(274.0, width * .8);
        final height = _bannerHeight(context, cardWidth);
        if (_width != width) {
          _width = width;
          _controller?.dispose();
          _controller = PageController(
            initialPage: _selected,
            viewportFraction: (cardWidth + 10) / width,
          );
        }
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                key: const Key('teaching-banners'),
                controller: _controller,
                itemCount: 3,
                onPageChanged: (index) => setState(() => _selected = index),
                itemBuilder: (context, index) => Center(
                  child: SizedBox(
                    width: cardWidth,
                    height: index == _selected ? height : height * .8,
                    child: AnimatedOpacity(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      opacity: index == _selected ? 1 : .5,
                      child: switch (index) {
                        0 => _CommunityBanner(
                          qrUrl: widget.highlights.communityQrUrl,
                          onTap: widget.onCommunity,
                        ),
                        1 => const _CreatorBanner(),
                        _ => _MemberBanner(
                          startingPrice: widget.highlights.startingPrice,
                          onTap: widget.onMembership,
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 3; index++)
                  Semantics(
                    label: switch (index) {
                      0 => l10n.teachingCommunityTitle,
                      1 => l10n.teachingCreatorTitle,
                      _ => l10n.teachingMemberTitle,
                    },
                    selected: _selected == index,
                    child: Container(
                      key: ValueKey('teaching-banner-indicator-$index'),
                      width: _selected == index ? 15 : 7,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(
                          alpha: _selected == index ? 1 : .2,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  double _bannerHeight(BuildContext context, double cardWidth) {
    final l10n = AppLocalizations.of(context)!;
    final (title, description, padding, copyWidth) = switch (_selected) {
      0 => (
        l10n.teachingCommunityTitle,
        widget.highlights.communityQrUrl.isEmpty
            ? l10n.teachingCommunityUnavailable
            : l10n.teachingCommunityDescription,
        20.0,
        widget.highlights.communityQrUrl.isEmpty
            ? cardWidth - 40
            : cardWidth - 50 - math.min(90, (cardWidth - 40) * .4),
      ),
      1 => (
        l10n.teachingCreatorTitle,
        l10n.teachingCreatorDescription,
        25.0,
        (cardWidth - 50) * .76,
      ),
      _ => (
        l10n.teachingMemberTitle,
        widget.highlights.startingPrice == null
            ? l10n.teachingMemberDescription
            : l10n.teachingMemberPrice(widget.highlights.startingPrice!),
        25.0,
        cardWidth - 50,
      ),
    };
    double measure(String text, double fontSize, double lineHeight, int lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: fontSize,
            height: lineHeight,
            letterSpacing: 0,
            fontWeight: fontSize == 20 ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: lines,
        ellipsis: '...',
      )..layout(maxWidth: copyWidth);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    return math.max(
      162,
      padding * 2 +
          measure(title, 20, 1.3, 2) +
          12 +
          measure(description, 14, 1.4, 3),
    );
  }
}

class _CreatorBanner extends StatelessWidget {
  const _CreatorBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7E7D9),
        borderRadius: BorderRadius.circular(26),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: constraints.maxWidth * .562,
                top: -constraints.maxHeight * .1168,
                height: constraints.maxHeight * 1.1168,
                width: constraints.maxWidth * .5657,
                child: Opacity(
                  opacity: .65,
                  child: Image.asset(
                    'assets/images/teaching_creator.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF7E7D9), Color(0x00F7E7D9)],
                    stops: [.35, .9],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(25),
                child: FractionallySizedBox(
                  widthFactor: .76,
                  alignment: Alignment.centerLeft,
                  child: _BannerCopy(
                    title: l10n.teachingCreatorTitle,
                    description: l10n.teachingCreatorDescription,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner({required this.qrUrl, this.onTap});

  final String qrUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: const Color(0xFFF8EBF3),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('teaching-community-banner'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _BannerCopy(
                  title: l10n.teachingCommunityTitle,
                  description: qrUrl.isEmpty
                      ? l10n.teachingCommunityUnavailable
                      : l10n.teachingCommunityDescription,
                ),
              ),
              if (qrUrl.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: math.min(
                    90,
                    (MediaQuery.sizeOf(context).width * .8 - 40) * .4,
                  ),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Image.network(
                      qrUrl,
                      fit: BoxFit.contain,
                      semanticLabel: l10n.teachingCommunityTitle,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberBanner extends StatelessWidget {
  const _MemberBanner({required this.startingPrice, required this.onTap});

  final String? startingPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: const Color(0xFFE3DCFA),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('teaching-membership-banner'),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: .3,
              child: Image.asset(
                'assets/images/teaching_member_background.png',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: _BannerCopy(
                title: l10n.teachingMemberTitle,
                description: startingPrice == null
                    ? l10n.teachingMemberDescription
                    : l10n.teachingMemberPrice(startingPrice!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 20,
          letterSpacing: 0,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 12),
      Flexible(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final lineHeight = MediaQuery.textScalerOf(context).scale(14) * 1.4;
            final lines = math.min(
              3,
              (constraints.maxHeight / lineHeight).floor(),
            );
            if (lines < 1) return const SizedBox();
            return Text(
              description,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                letterSpacing: 0,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            );
          },
        ),
      ),
    ],
  );
}
