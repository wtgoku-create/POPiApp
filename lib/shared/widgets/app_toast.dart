import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../../app/theme.dart';

class AppToast {
  const AppToast._();

  static ToastificationItem success(BuildContext context, String message) {
    return _show(
      context,
      message: message,
      type: ToastificationType.success,
      icon: Icons.check_circle_outline,
    );
  }

  static ToastificationItem error(BuildContext context, String message) {
    return _show(
      context,
      message: message,
      type: ToastificationType.error,
      icon: Icons.error_outline,
    );
  }

  static ToastificationItem info(BuildContext context, String message) {
    return _show(
      context,
      message: message,
      type: ToastificationType.info,
      icon: Icons.info_outline,
    );
  }

  static ToastificationItem _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    required IconData icon,
  }) {
    return toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topCenter,
      icon: Icon(icon),
      description: Text(message),
      borderRadius: BorderRadius.circular(AppRadii.card),
      boxShadow: highModeShadow,
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.always),
    );
  }
}
