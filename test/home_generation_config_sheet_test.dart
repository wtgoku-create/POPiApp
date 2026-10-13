import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/home_generation_config_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

import 'support/home_creation_fixtures.dart';

const sessionId = '11111111-1111-4111-8111-111111111111';

HomeCreationFixture configFixture() {
  final fixture = HomeCreationFixture();
  fixture.modelCatalogs['video'] = [
    {
      'id': '501',
      'name': 'Sora 2',
      'available': true,
      'mediaType': 'video',
      'parameters': [
        {
          'name': 'resolution',
          'label': '分辨率',
          'type': 'string',
          'required': true,
          'default': '720p',
          'options': ['720p', '1080p'],
        },
        {
          'name': 'ratio',
          'label': '比例',
          'type': 'string',
          'required': true,
          'default': '16:9',
          'options': ['16:9', '3:2', '4:3', '1:1', '9:16', '2:3', '3:4'],
        },
        {
          'name': 'duration',
          'label': '时长',
          'type': 'integer',
          'required': false,
          'default': 20,
          'min': 1,
          'max': 180,
          'step': 1,
        },
      ],
    },
    {
      'id': '502',
      'name': 'Veo 3.1',
      'available': true,
      'mediaType': 'video',
      'parameters': [
        {
          'name': 'duration',
          'label': '时长',
          'type': 'integer',
          'required': true,
          'default': 8,
          'options': [4, 8, 12],
        },
      ],
    },
  ];
  fixture.modelCatalogs['image'] = [
    {
      'id': '601',
      'name': 'Image model',
      'available': true,
      'mediaType': 'image',
      'parameters': [
        {
          'name': 'resolution',
          'label': '分辨率',
          'type': 'string',
          'required': true,
          'default': '1k',
          'options': ['1k', '2k'],
        },
        {
          'name': 'ratio',
          'label': '比例',
          'type': 'string',
          'required': true,
          'default': '1:1',
          'options': ['1:1', '3:4'],
        },
      ],
    },
  ];
  fixture.videoPreference = {
    'modelId': '501',
    'params': {'resolution': '720p', 'ratio': '16:9', 'duration': 20},
  };
  fixture.imagePreference = {
    'modelId': '601',
    'params': {'resolution': '1k', 'ratio': '1:1'},
  };
  return fixture;
}

Future<void> pumpConfig(
  WidgetTester tester,
  HomeCreationFixture fixture, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  double scale = 1,
  bool dark = false,
  bool forGeneration = false,
  HomeConfig? saved,
  ValueChanged<HomeGenerationConfiguration?>? onSaved,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => IconButton(
            key: const Key('open-config'),
            icon: const Icon(Icons.tune),
            onPressed: () async {
              final result = await AppSheet.show<HomeGenerationConfiguration>(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
                useSafeArea: false,
                backgroundColor: Colors.transparent,
                builder: (_) => HomeGenerationConfigSheet(
                  repository: fixture.repository,
                  sessionId: sessionId,
                  forGeneration: forGeneration,
                  saved: saved,
                ),
              );
              onSaved?.call(result);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-config')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> configVisible(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      key.startsWith('home-config-model') ? -150 : 150,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-generation-config-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> configTap(WidgetTester tester, String key) async {
  await configVisible(tester, key);
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'generation edits only video and returns local config without preferences',
    (tester) async {
      final fixture = configFixture();
      HomeGenerationConfiguration? result;
      await pumpConfig(
        tester,
        fixture,
        forGeneration: true,
        saved: const HomeConfig(
          modelId: '501',
          params: {'resolution': '1080p', 'ratio': '16:9', 'duration': 12},
        ),
        onSaved: (value) => result = value,
      );
      expect(find.text('图片偏好'), findsNothing);
      expect(find.byKey(const Key('role-segment-1')), findsNothing);
      expect(
        fixture.requests
            .where((request) => request.path.endsWith('/media-models'))
            .map((request) => request.queryParameters['mediaType']),
        ['video'],
      );
      await configVisible(tester, 'home-config-duration-slider');
      expect(
        tester
            .widget<Slider>(
              find.byKey(const Key('home-config-duration-slider')),
            )
            .value,
        11,
      );
      await configTap(tester, 'home-config-ratio-9:16');
      fixture.failPreferenceSaveOnce = true;
      await configTap(tester, 'home-config-confirm');
      expect(result?.config?.toJson(), {
        'modelId': '501',
        'params': {'resolution': '1080p', 'ratio': '9:16', 'duration': 12},
      });
      expect(result?.points, 42);
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/session-media-preferences'),
        ),
        isEmpty,
      );
      expect((fixture.videoPreference['params'] as Map)['resolution'], '720p');
      await pumpConfig(
        tester,
        fixture,
        forGeneration: true,
        saved: result!.config,
      );
      await configVisible(tester, 'home-config-duration-slider');
      expect(
        tester
            .widget<Slider>(
              find.byKey(const Key('home-config-duration-slider')),
            )
            .value,
        11,
      );
      await configTap(tester, 'home-config-confirm');
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/session-media-preferences'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generation without a saved config uses the video catalog defaults',
    (tester) async {
      final fixture = configFixture();
      fixture.videoPreference = {
        'modelId': '502',
        'params': {'duration': 12},
      };
      HomeGenerationConfiguration? result;
      await pumpConfig(
        tester,
        fixture,
        forGeneration: true,
        onSaved: (value) => result = value,
      );
      await configTap(tester, 'home-config-confirm');
      expect(result?.config?.modelId, '501');
      expect(result?.config?.params['duration'], 20);
      expect(result?.points, 42);
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/session-media-preferences'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'loads both catalogs and saved preferences; confirmation persists only changed types',
    (tester) async {
      final fixture = configFixture();
      HomeGenerationConfiguration? result;
      await pumpConfig(tester, fixture, onSaved: (value) => result = value);
      expect(
        fixture.requests
            .where((request) => request.path.endsWith('/media-models'))
            .map((request) => request.queryParameters['mediaType']),
        unorderedEquals(['video', 'image']),
      );
      expect(
        fixture.requests
            .singleWhere(
              (request) => request.path.endsWith('/session-media-preferences'),
            )
            .queryParameters,
        {'sessionId': sessionId},
      );
      await configTap(tester, 'home-config-ratio-9:16');
      await configTap(tester, 'role-segment-1');
      expect(find.text('Sora 2'), findsNothing);
      await configTap(tester, 'home-config-resolution-2k');
      await configTap(tester, 'home-config-confirm');
      expect(result?.config?.params['ratio'], '9:16');
      expect(result?.points, isNull);
      final writes = fixture.requests
          .where((request) => request.method == 'PUT')
          .toList();
      expect(writes, hasLength(2));
      expect(writes[0].data, {
        'sessionId': sessionId,
        'mediaType': 'video',
        'config': {
          'modelId': '501',
          'params': {'resolution': '720p', 'ratio': '9:16', 'duration': 20},
        },
      });
      expect(writes[1].data['mediaType'], 'image');
      await tester.tap(find.byKey(const Key('open-config')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-config-duration-slider')),
        150,
        scrollable: find.descendant(
          of: find.byKey(const Key('home-generation-config-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        tester
            .widget<Slider>(
              find.byKey(const Key('home-config-duration-slider')),
            )
            .value,
        19,
      );
      await configTap(tester, 'home-config-confirm');
      expect(
        fixture.requests.where((request) => request.method == 'PUT'),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save failure keeps edits and blocks returning a generation config until retry succeeds',
    (tester) async {
      final fixture = configFixture();
      HomeGenerationConfiguration? result;
      await pumpConfig(tester, fixture, onSaved: (value) => result = value);
      await configTap(tester, 'home-config-ratio-9:16');
      fixture.failPreferenceSaveOnce = true;
      await configTap(tester, 'home-config-confirm');
      expect(result, isNull);
      expect(
        find.byKey(const Key('home-generation-config-sheet')),
        findsOneWidget,
      );
      await configTap(tester, 'home-config-confirm');
      expect(result?.config?.params['ratio'], '9:16');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duration uses backend bounds and discrete options without automatic mode',
    (tester) async {
      final fixture = configFixture();
      await pumpConfig(tester, fixture);
      await configVisible(tester, 'home-config-duration-slider');
      expect(find.byKey(const Key('home-config-duration-auto')), findsNothing);
      expect(find.text('智能选择'), findsNothing);
      expect(
        tester
            .widget<Slider>(
              find.byKey(const Key('home-config-duration-slider')),
            )
            .value,
        19,
      );
      await configTap(tester, 'home-config-model-502');
      await configVisible(tester, 'home-config-duration-slider');
      final slider = tester.widget<Slider>(
        find.byKey(const Key('home-config-duration-slider')),
      );
      expect(slider.divisions, 2);
      expect(find.byKey(const Key('home-config-duration-auto')), findsNothing);
      slider.onChanged!(2);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await configTap(tester, 'home-config-confirm');
      expect((fixture.videoPreference['params'] as Map)['duration'], 12);
      expect(
        (fixture.videoPreference['params'] as Map).containsKey('ratio'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final legacy in [null, 'auto', 'automatic']) {
    testWidgets('legacy duration $legacy uses a numeric catalog option', (
      tester,
    ) async {
      final fixture = configFixture();
      final model = fixture.modelCatalogs['video']!.first;
      final parameters = model['parameters'] as List;
      final duration = parameters.last as Map;
      duration['default'] = 'auto';
      duration['options'] = ['auto', 'automatic', 5, 10];
      final params = fixture.videoPreference['params'] as Map;
      if (legacy == null) {
        params.remove('duration');
      } else {
        params['duration'] = legacy;
      }
      await pumpConfig(tester, fixture);
      await configVisible(tester, 'home-config-duration-slider');
      expect(find.text('智能选择'), findsNothing);
      expect(
        find.byKey(const Key('home-config-duration-slider')),
        findsOneWidget,
      );
      await configTap(tester, 'home-config-confirm');
      expect((fixture.videoPreference['params'] as Map)['duration'], 5);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, locale, scale, dark) in [
    (const Size(390, 844), const Locale('zh'), 1.0, false),
    (const Size(320, 640), const Locale('en'), 1.5, true),
    (const Size(1024, 768), const Locale('en'), 1.0, false),
  ]) {
    testWidgets('controls and fixed confirmation fit $size with scale $scale', (
      tester,
    ) async {
      final fixture = configFixture();
      await pumpConfig(
        tester,
        fixture,
        size: size,
        locale: locale,
        scale: scale,
        dark: dark,
      );
      final button = find.byKey(const Key('home-config-confirm'));
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(size.height));
      expect(tester.getTopLeft(button).dx, greaterThanOrEqualTo(20));
      await configTap(tester, 'home-config-ratio-3:4');
      await configVisible(tester, 'home-config-duration-slider');
      await configTap(tester, 'role-segment-1');
      await configTap(tester, 'home-config-resolution-2k');
      expect(tester.takeException(), isNull);
      await configTap(tester, 'home-config-confirm');
    });
  }

  testWidgets('dismissing edits leaves conversation preferences intact', (
    tester,
  ) async {
    final fixture = configFixture();
    await pumpConfig(tester, fixture);
    await configTap(tester, 'home-config-ratio-9:16');
    Navigator.of(
      tester.element(find.byKey(const Key('home-generation-config-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((request) => request.method == 'PUT'),
      isEmpty,
    );
    expect((fixture.videoPreference['params'] as Map)['ratio'], '16:9');
  });
}
