import 'package:flutter/material.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/role_guide/domain/role_guide_draft.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_generation_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Uri.base.queryParameters['theme'] == 'dark'
        ? AppTheme.dark
        : AppTheme.light,
    locale: Locale(Uri.base.queryParameters['lang'] ?? 'zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const _PreviewPage(),
  );
}

class _PreviewPage extends StatefulWidget {
  const _PreviewPage();
  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  RoleGenerationSettings _settings = const RoleGenerationSettings(duration: 20);
  bool _open = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  Future<void> _show() async {
    if (_open) return;
    _open = true;
    final settings = await AppSheet.show<RoleGenerationSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => RoleGenerationSheet(
        initialSettings: _settings,
        videoOnly: Uri.base.queryParameters['mode'] == 'generation',
      ),
    );
    _open = false;
    if (mounted && settings != null) setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: IconButton(
        icon: const Icon(Icons.tune),
        tooltip: AppLocalizations.of(context)!.roleModelParameters,
        onPressed: _show,
      ),
    ),
  );
}
