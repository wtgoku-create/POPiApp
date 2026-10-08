import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attachments/data/device_gallery_repository.dart';
import '../../features/attachments/domain/gallery_repository.dart';

final galleryRepositoryProvider = Provider<GalleryRepository>(
  (ref) => DeviceGalleryRepository(),
);
