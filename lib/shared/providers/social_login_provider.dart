import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/douyin_login_service.dart';

final douyinLoginServiceProvider = Provider<DouyinLoginService>(
  (ref) => const DouyinLoginService(),
);
