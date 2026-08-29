import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final safeAreaInsetsProvider =
    NotifierProvider<SafeAreaInsetsController, EdgeInsets>(
  SafeAreaInsetsController.new,
);

class SafeAreaInsetsController extends Notifier<EdgeInsets> {
  @override
  EdgeInsets build() => EdgeInsets.zero;

  void update(EdgeInsets insets) {
    if (state == insets) return;
    state = insets;
  }
}
