import 'package:flutter/material.dart';

import '../core/platform/app_platform.dart';
import 'business_workspace_app.dart';
import 'v2_app.dart';

/// One entry point selects the complete Web workspace or the native interface.
class PopiApp extends StatelessWidget {
  const PopiApp({super.key});

  @override
  Widget build(BuildContext context) =>
      AppPlatform.current.isWeb ? const BusinessWorkspaceApp() : const V2App();
}
