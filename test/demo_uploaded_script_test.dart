import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_script_detail_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('uploaded script loads lazily and copies fetched text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    final repository = _ScriptRepository(storage);
    addTearDown(repository.dispose);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    const asset = DemoAsset(
      id: 'script-1',
      title: '南极分镜.md',
      kind: DemoAssetKind.script,
      cover: '',
      contentUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/script-1/content',
      mimeType: 'text/markdown',
      sizeBytes: 12,
    );
    expect(asset.body, isEmpty);

    await tester.pumpWidget(
      ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DemoScriptDetailPage(asset: asset, repository: repository),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(repository.reads, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('# 南极\n第一镜'), findsNothing);

    repository.body.complete('# 南极\n第一镜');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MarkdownMessage>(find.byType(MarkdownMessage)).text,
      '# 南极\n第一镜',
    );

    await tester.tap(find.byTooltip('复制'));
    await tester.pump();
    expect(clipboardText, '# 南极\n第一镜');
    await tester.pump(const Duration(seconds: 4));
  });
}

class _ScriptRepository extends DemoRepository {
  _ScriptRepository(super.storage);

  final body = Completer<String>();
  int reads = 0;

  @override
  Future<String> readAssetText(DemoAsset asset) {
    reads += 1;
    return body.future;
  }
}
