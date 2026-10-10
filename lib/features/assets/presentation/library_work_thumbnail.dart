import 'package:flutter/material.dart';

import '../../role_guide/presentation/widgets/role_guide_controls.dart';
import '../domain/library_work.dart';

/// Shared image/video preview for library selection and composer attachments.
class LibraryWorkThumbnail extends StatelessWidget {
  const LibraryWorkThumbnail({required this.work, super.key});

  final LibraryWork work;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: work.previewUrl.startsWith('assets/')
              ? AssetImage(work.previewUrl)
              : NetworkImage(work.previewUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(
            color: roleGuideTint(context),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
        if (work.isVideo)
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
          ),
      ],
    ),
  );
}
