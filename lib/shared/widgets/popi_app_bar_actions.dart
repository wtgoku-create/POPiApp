import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'popi_activity_button.dart';

/// Reserves navigation space and a fixed-size activity entry beside the balance.
class PopiAppBarActions extends StatelessWidget {
  const PopiAppBarActions({
    required this.membershipEntry,
    this.leadingWidth = 80,
    this.rightPadding = 15,
    super.key,
  });

  final Widget membershipEntry;
  final double leadingWidth;
  final double rightPadding;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: math.max(
        53 + rightPadding,
        MediaQuery.sizeOf(context).width - leadingWidth - 8,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.only(right: rightPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PopiActivityButton(),
          const SizedBox(width: 10),
          Flexible(child: membershipEntry),
        ],
      ),
    ),
  );
}
