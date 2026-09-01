import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../../app/theme.dart';

class AppToast {
  const AppToast._();

  static const _infoColor = Color(0xFF2563EB);
  static const _errorColor = Color(0xFFD92D20);

  static ToastificationItem success(BuildContext context, String message) {
    return _show(
      context,
      message: message,
      type: ToastificationType.success,
      icon: Icons.check_rounded,
      accentColor: AppColors.success,
    );
  }

  static ToastificationItem error(BuildContext context, String message) {
    return _show(
      context,
      message: message,
      type: ToastificationType.error,
      icon: Icons.close_rounded,
      accentColor: _errorColor,
    );
  }

  static ToastificationItem info(BuildContext context, String message) {
    return _show(
      context,
      message: message,
      type: ToastificationType.info,
      icon: Icons.info_rounded,
      accentColor: _infoColor,
    );
  }

  static ToastificationItem _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    required IconData icon,
    required Color accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topCenter,
      primaryColor: accentColor,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      icon: _ToastStatusIcon(icon: icon, color: accentColor),
      title: Text(
        message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      sizeConstraints: const BoxConstraints(minHeight: 48, maxWidth: 320),
      borderRadius: BorderRadius.circular(AppRadii.small),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.always,
        buttonBuilder: (context, onClose) => Tooltip(
          message: MaterialLocalizations.of(context).closeButtonTooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: SizedBox.square(
                dimension: 30,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStatusIcon extends StatelessWidget {
  const _ToastStatusIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 14, color: AppColors.surface),
    );
  }
}
