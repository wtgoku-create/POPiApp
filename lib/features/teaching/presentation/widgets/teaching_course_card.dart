import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/teaching.dart';

class TeachingCourseCard extends StatelessWidget {
  const TeachingCourseCard({
    required this.course,
    required this.memberLabels,
    required this.onTap,
    super.key,
  });

  final TeachingCourse course;
  final Map<int, String> memberLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final level = course.lowestKnownMemberLevel(memberLabels);
    final title = course.name.isEmpty ? l10n.teachingUntitled : course.name;
    final badgeLabel = course.memberLevels.isEmpty
        ? l10n.teachingFree
        : memberLabels[level];
    final badgeColor = level == null || level <= 0
        ? AppColors.textPrimary
        : level >= 3
        ? const Color(0xFFFF9A27)
        : AppColors.brand;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      child: Material(
        color: dark
            ? scheme.surfaceContainer
            : Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: course.coverUrl.isEmpty
                          ? Icon(
                              Icons.school_outlined,
                              color: scheme.onSurfaceVariant,
                              size: 36,
                            )
                          : Image.network(
                              course.coverUrl,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.broken_image_outlined,
                                color: scheme.onSurfaceVariant,
                                size: 32,
                              ),
                            ),
                    ),
                    if (course.tag.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              course.tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      LayoutBuilder(
                        builder: (context, constraints) => Row(
                          children: [
                            Expanded(
                              child: course.instructorName.isEmpty
                                  ? const SizedBox()
                                  : Row(
                                      children: [
                                        if (course
                                            .instructorAvatarUrl
                                            .isNotEmpty) ...[
                                          ClipOval(
                                            child: Image.network(
                                              course.instructorAvatarUrl,
                                              width: 20,
                                              height: 20,
                                              fit: BoxFit.cover,
                                              excludeFromSemantics: true,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.person_outline,
                                                    size: 20,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        Expanded(
                                          child: Text(
                                            l10n.teachingInstructor(
                                              course.instructorName,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              letterSpacing: 0,
                                              color: dark
                                                  ? scheme.onSurfaceVariant
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            if (badgeLabel != null) ...[
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * .48,
                                ),
                                child: Container(
                                  key: ValueKey('teaching-badge-${course.id}'),
                                  constraints: BoxConstraints(
                                    minWidth: math.min(
                                      55,
                                      constraints.maxWidth * .48,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          badgeLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            letterSpacing: 0,
                                            height: 1,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (level != null && level > 0) ...[
                                        const SizedBox(width: 3),
                                        const AppSvgIcon.asset(
                                          'teaching_member_lock',
                                          size: 12,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
