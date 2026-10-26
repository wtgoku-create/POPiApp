import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_image_cache.dart';

void main() {
  testWidgets('header follows the current user avatar across both tabs', (
    tester,
  ) async {
    final originalCache = AppImageCache.debugCacheManager;
    AppImageCache.debugCacheManager = MemoryImageCache();
    addTearDown(() => AppImageCache.debugCacheManager = originalCache);
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DemoHomePage(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byTooltip('个人资料');
    final image = find.descendant(of: header, matching: find.byType(Image));
    final remote = find.descendant(
      of: header,
      matching: find.byType(AppNetworkImage),
    );
    void expectDefaultAvatar() {
      expect(remote, findsNothing);
      expect(
        tester.widget<Image>(image).image,
        isA<AssetImage>().having(
          (asset) => asset.assetName,
          'assetName',
          'assets/icons/common_user_avatar.png',
        ),
      );
    }

    expectDefaultAvatar();
    final originalRect = tester.getRect(header);
    const firstUrl = 'https://example.com/first-avatar.png';
    const updatedUrl = 'https://example.com/updated-avatar.png';
    final user = container.read(userProvider.notifier);
    for (final url in [firstUrl, updatedUrl]) {
      await user.setUser(
        User(id: 'current-user', name: '当前用户', email: '', avatarUrl: url),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppNetworkImage>(remote).url, url);
      expect(tester.widget<AppNetworkImage>(remote).fit, BoxFit.cover);
      expect(tester.getRect(header), originalRect);
      if (url == firstUrl) {
        await tester.tap(find.byKey(const Key('demo-tab-1')));
        await tester.pumpAndSettle();
        expect(tester.widget<AppNetworkImage>(remote).url, firstUrl);
      }
    }

    for (final url in <String?>['', null]) {
      await user.setUser(
        User(id: 'current-user', name: '当前用户', email: '', avatarUrl: url),
      );
      await tester.pumpAndSettle();
      expectDefaultAvatar();
    }
    expect(tester.takeException(), isNull);
  });
}
