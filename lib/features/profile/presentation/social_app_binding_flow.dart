import 'package:flutter/material.dart';

import '../../../core/platform/app_platform.dart';
import '../../../shared/type/social_app_type.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../data/social_app_binding_repository.dart';
import '../domain/social_app_binding.dart';
import 'widgets/web_wechat_binding_dialog.dart';

/// Selects browser QR linking or native SDK authorization for existing accounts.
abstract final class SocialAppBindingFlow {
  static Future<SocialAppBinding?> bind({
    required BuildContext context,
    required SocialAppBindingRepository repository,
    required SocialAppType app,
    required bool Function() isCurrentUser,
  }) {
    if (!AppPlatform.current.isWeb) {
      return repository.bind(app, isCurrentUser: isCurrentUser);
    }
    if (!isCurrentUser() || app != SocialAppType.wechat) {
      return Future.value();
    }
    return AppDialog.show<SocialAppBinding>(
      context: context,
      builder: (_) => WebWechatBindingDialog(
        repository: repository,
        isCurrentUser: isCurrentUser,
      ),
    );
  }
}
