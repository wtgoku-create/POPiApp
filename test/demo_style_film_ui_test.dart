import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/clipboard/clipboard_images.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_style_film_job_card.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_style_film_review_sheet.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_style_film_sheet.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Widget _app(Widget child, {TargetPlatform? platform}) => ProviderScope(
  child: ToastificationWrapper(
    child: MaterialApp(
      theme: AppTheme.light.copyWith(platform: platform),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('catalog selects only ready styles and keeps real parameters', (
    tester,
  ) async {
    DemoStyleFilmSelection? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDemoStyleFilmSheet(
                context: context,
                loadCatalog:
                    ({
                      required query,
                      category,
                      required page,
                      required pageSize,
                    }) async => const DemoStyleFilmCatalog(
                      available: true,
                      total: 2,
                      readyCount: 1,
                      page: 1,
                      pageCount: 1,
                      categories: [
                        DemoStyleFilmCategory(
                          id: 'painting',
                          nameZh: '手绘与绘画',
                          nameEn: 'Painting',
                        ),
                      ],
                      supports: DemoStyleFilmSupports(
                        durations: [15, 30],
                        aspectRatios: ['9:16', '16:9'],
                        soundtracks: ['none', 'music'],
                      ),
                      list: [
                        DemoStyleFilmStyle(
                          id: 'impasto',
                          nameZh: '油画厚涂',
                          categoryId: 'painting',
                          supported: true,
                          ready: true,
                        ),
                        DemoStyleFilmStyle(
                          id: 'three-d',
                          nameZh: '复杂 3D',
                          ready: false,
                          reasonUnavailableCode: 'unsupported_style',
                        ),
                      ],
                    ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-style-film-sheet')), findsOneWidget);
    expect(find.text('可制作 1 种'), findsOneWidget);
    expect(find.text('手绘与绘画'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('demo-style-film-style-three-d')),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('demo-style-film-confirm')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('demo-style-film-style-impasto')),
    );
    await tester.pumpAndSettle();
    void selectChoice(String label) {
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(ChoiceChip),
      );
      tester.widget<ChoiceChip>(chip).onSelected?.call(true);
    }

    selectChoice('30 s');
    await tester.pump();
    selectChoice('16:9');
    await tester.pump();
    selectChoice('原创配乐');
    await tester.pump();
    tester
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(const Key('demo-style-film-confirm')),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed
        ?.call();
    await tester.pumpAndSettle();

    expect(result?.styleId, 'impasto');
    expect(result?.durationSeconds, 30);
    expect(result?.aspectRatio, '16:9');
    expect(result?.soundtrack, 'music');
    expect(result?.storyboardReview, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero-ready catalog stays browsable with localized reasons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DemoStyleFilmSheet(
          loadCatalog:
              ({
                required query,
                category,
                required page,
                required pageSize,
              }) async => const DemoStyleFilmCatalog(
                total: 59,
                readyCount: 0,
                reasonUnavailableCode: 'runtime_unavailable',
                categories: [
                  DemoStyleFilmCategory(
                    id: 'documentary',
                    nameZh: '剪辑与纪实',
                    nameEn: 'Documentary',
                  ),
                ],
                pageCount: 1,
                list: [
                  DemoStyleFilmStyle(
                    id: 'caption-news',
                    nameZh: '字幕新闻',
                    reasonUnavailable: 'This style requires an adapter',
                    reasonUnavailableCode: 'unverified_style',
                  ),
                ],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('59 种风格'), findsOneWidget);
    expect(find.text('可制作 0 种'), findsOneWidget);
    expect(find.textContaining('可以浏览全部风格'), findsOneWidget);
    expect(find.text('待验证'), findsOneWidget);
    expect(find.textContaining('This style'), findsNothing);
    expect(find.text('当前没有已验证可制作的风格'), findsOneWidget);
    final footer = tester.widget<Container>(
      find.byKey(const Key('demo-style-film-footer')),
    );
    final decoration = footer.decoration! as BoxDecoration;
    expect(
      decoration.color,
      Theme.of(
        tester.element(find.byKey(const Key('demo-style-film-footer'))),
      ).colorScheme.surface,
    );
    final hint = tester.widget<Text>(
      find.byKey(const Key('demo-style-film-footer-hint')),
    );
    expect(
      hint.style?.color,
      Theme.of(
        tester.element(find.byKey(const Key('demo-style-film-footer-hint'))),
      ).colorScheme.onSurfaceVariant,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('demo-style-film-bottom-spacer')))
          .height,
      greaterThanOrEqualTo(180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('storyboard revision requires notes and submits whole review', (
    tester,
  ) async {
    String? action;
    String? notes;
    await tester.pumpWidget(
      _app(
        DemoStyleFilmReviewSheet(
          job: const DemoStyleFilmJob(
            jobId: 'film-1',
            title: '窗台的等待',
            revision: 3,
            state: 'awaiting_storyboard',
            allowedActions: ['approve', 'revise'],
            storyboard: [
              DemoStyleFilmStoryboard(
                id: 'shot-1',
                title: '等待',
                description: '橘猫看向雨中的街道。',
                durationSeconds: 5,
              ),
              DemoStyleFilmStoryboard(
                id: 'shot-2',
                title: '归来',
                description: '门锁响起，暖光从门缝进入。',
                startSeconds: 5,
                durationSeconds: 5,
              ),
              DemoStyleFilmStoryboard(
                id: 'shot-3',
                title: '相遇',
                description: '橘猫跳下窗台，雨也停了。',
                startSeconds: 10,
                durationSeconds: 5,
              ),
            ],
          ),
          onReview: (_, nextAction, nextNotes) async {
            action = nextAction;
            notes = nextNotes;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-style-film-revise')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('demo-style-film-revision-notes')).hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('demo-style-film-revision-notes')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    final submit = find.byKey(const Key('demo-style-film-submit-revision'));
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(of: submit, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('demo-style-film-revision-notes')),
      '让开场更安静，结尾加快节奏。',
    );
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('demo-style-film-revision-notes')).hitTestable(),
      findsOneWidget,
    );
    expect(submit.hitTestable(), findsOneWidget);
    tester
        .widget<FilledButton>(
          find.descendant(of: submit, matching: find.byType(FilledButton)),
        )
        .onPressed
        ?.call();
    await tester.pump();
    expect(action, 'revise');
    expect(notes, '让开场更安静，结尾加快节奏。');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown planning failure exposes explicit manual retry', (
    tester,
  ) async {
    String? action;
    await tester.pumpWidget(
      _app(
        DemoStyleFilmReviewSheet(
          job: const DemoStyleFilmJob(
            jobId: 'film-unknown',
            revision: 2,
            state: 'failed_planning_unknown',
            allowedActions: ['revise'],
          ),
          onReview: (_, nextAction, _) async {
            action = nextAction;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(find.byKey(const Key('demo-style-film-revise')))
        .onPressed
        ?.call();
    await tester.pump();
    final retry = find.byKey(const Key('demo-style-film-submit-revision'));
    tester
        .widget<FilledButton>(
          find.descendant(of: retry, matching: find.byType(FilledButton)),
        )
        .onPressed
        ?.call();
    await tester.pump();
    expect(action, 'revise');
    expect(tester.takeException(), isNull);
  });

  testWidgets('film job cards present every server-authoritative state', (
    tester,
  ) async {
    final jobs = const [
      DemoStyleFilmJob(jobId: 'planning', state: 'planning'),
      DemoStyleFilmJob(jobId: 'storyboard', state: 'awaiting_storyboard'),
      DemoStyleFilmJob(jobId: 'rendering', state: 'rendering'),
      DemoStyleFilmJob(jobId: 'completed', state: 'completed'),
      DemoStyleFilmJob(
        jobId: 'failed',
        state: 'failed_planning',
        allowedActions: ['revise'],
      ),
    ];
    await tester.pumpWidget(
      _app(
        ListView.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => DemoStyleFilmJobCard(
            job: jobs[index],
            onOpen: () {},
            onOpenOutput: jobs[index].isCompleted ? () {} : null,
            onRetry: jobs[index].isFailed ? () {} : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('正在准备分镜'), findsOneWidget);
    expect(find.text('分镜待你确认'), findsOneWidget);
    expect(find.text('正在制作短片'), findsOneWidget);
    expect(find.text('短片已完成'), findsOneWidget);
    expect(find.text('短片制作失败'), findsOneWidget);
    for (final job in jobs) {
      expect(
        find.byKey(ValueKey('demo-style-film-job-${job.jobId}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bot skill switch applies only after a successful save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _SettingsRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _app(
        DemoSettingsPage(
          repository: repository,
          sessionId: 'inspiration',
          initialTab: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    final toggle = find.byKey(
      const ValueKey('demo-style-film-capability-popi'),
    );
    expect(find.bySemanticsLabel(RegExp(r'制作风格短片.*POPi')), findsOneWidget);
    semantics.dispose();
    await tester.ensureVisible(toggle);
    tester.widget<Switch>(toggle).onChanged?.call(true);
    await tester.pumpAndSettle();
    expect(
      repository.session('inspiration').skillsFor('popi'),
      contains(demoStyleFilmSkillId),
    );

    repository.failNext = true;
    tester.widget<Switch>(toggle).onChanged?.call(false);
    await tester.pumpAndSettle();
    expect(
      repository.session('inspiration').skillsFor('popi'),
      contains(demoStyleFilmSkillId),
    );
    expect(
      tester.widget<Switch>(toggle).value,
      isFalse,
      reason: 'the unsaved switch draft stays visible for the original action',
    );
    expect(find.text('能力设置未保存，已保留你的修改。'), findsWidgets);
    expect(tester.takeException(), isNull);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
  });

  testWidgets('composer gates both style entries and omits hidden selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _ChatRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        activeMemberId: 'popi',
        memberSkills: const {
          'popi': [demoStyleFilmSkillId],
        },
        memberBotIds: const {'popi': 'builtin:popi'},
        filmDrafts: const {
          'builtin:popi': DemoStyleFilmSelection(
            styleId: 'impasto',
            styleNameZh: '油画厚涂',
          ),
        },
      ),
    );
    expect(
      repository.session('inspiration').skillsFor('popi'),
      contains(demoStyleFilmSkillId),
    );
    expect(
      repository.styleFilmDraft('inspiration', 'builtin:popi')?.styleId,
      'impasto',
    );
    await tester.pumpWidget(
      _app(DemoChatPage(repository: repository, sessionId: 'inspiration')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DemoChatPage), findsOneWidget);
    expect(
      repository.sessions.map((session) => session.id),
      contains('inspiration'),
    );
    expect(find.byType(PopiMessageComposer), findsOneWidget);
    expect(
      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .contextChips,
      hasLength(2),
    );
    expect(find.byKey(const Key('demo-style-film-style-chip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-composer-add-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-add-style-film')), findsOneWidget);
    final attachment = repository.assets.first;
    await tester.tap(find.byKey(const Key('demo-add-from-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(attachment.id)));
    await tester.pumpAndSettle();

    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('把橘猫的等待做成短片。');
    await tester.pumpAndSettle();
    tester
        .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
        .onSubmitted('把橘猫的等待做成短片。');
    await tester.pumpAndSettle();
    expect(find.text('当前风格短片仅支持文字主题，请先移除附件和内容角色。'), findsWidgets);
    expect(repository.invocations, isEmpty);
    expect(composer.controller.markdown, '把橘猫的等待做成短片。');
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('popi-remove-selected-asset-${attachment.id}')),
    );
    await tester.pumpAndSettle();
    tester
        .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
        .onSubmitted('把橘猫的等待做成短片。');
    await tester.pumpAndSettle();
    expect(find.text('确认创作简报'), findsOneWidget);
    await tester.tap(find.text('使用这个风格'));
    await tester.pumpAndSettle();
    expect(repository.invocations.single?.selection.styleId, 'impasto');

    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        memberSkills: const {'popi': <String>[]},
        filmDrafts: const {
          'builtin:popi': DemoStyleFilmSelection(
            styleId: 'impasto',
            styleNameZh: '油画厚涂',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-style-film-style-chip')), findsNothing);
    await tester.tap(find.byKey(const Key('demo-composer-add-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-add-style-film')), findsNothing);
    await tester.tap(find.byKey(const Key('demo-composer-add-menu')));
    await composer.controller.setText('普通消息，不带隐藏风格。');
    await tester.pumpAndSettle();
    tester
        .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
        .onSubmitted('普通消息，不带隐藏风格。');
    await tester.pumpAndSettle();
    expect(repository.invocations.last, isNull);
    expect(
      repository.session('inspiration').filmDrafts['builtin:popi']?.styleId,
      'impasto',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('active film planning stays busy without exposing Stop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _ChatRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    repository.setRun(running: true, canStop: false);
    await tester.pumpWidget(
      _app(DemoChatPage(repository: repository, sessionId: 'inspiration')),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('popi-running-indicator')), findsOneWidget);
    expect(find.byTooltip('停止回复'), findsNothing);
    expect(find.byKey(const Key('popi-send-button')), findsNothing);

    repository.setRun(running: true, canStop: true);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('popi-running-indicator')), findsNothing);
    expect(find.byTooltip('停止回复'), findsOneWidget);
    expect(find.byKey(const Key('popi-send-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit paste image keeps text and adds an uploaded attachment',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _ChatRepository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      addTearDown(repository.dispose);
      final clipboard = _ClipboardService();
      await tester.pumpWidget(
        _app(
          DemoChatPage(
            repository: repository,
            sessionId: 'inspiration',
            clipboardImageService: clipboard,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final composer = tester.widget<PopiMessageComposer>(
        find.byType(PopiMessageComposer),
      );
      await composer.controller.setText('保留当前文字');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-composer-add-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-paste-image')));
      await tester.pumpAndSettle();

      expect(clipboard.reads, 1);
      expect(composer.controller.markdown, '保留当前文字');
      expect(
        find.byKey(const ValueKey('popi-selected-asset-clipboard-asset')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty image paste falls back to ordinary clipboard text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _ChatRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': '普通剪贴板文字'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final clipboard = _EmptyClipboardService();
    await tester.pumpWidget(
      _app(
        DemoChatPage(
          repository: repository,
          sessionId: 'inspiration',
          clipboardImageService: clipboard,
        ),
        platform: TargetPlatform.macOS,
      ),
    );
    await tester.pumpAndSettle();
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(composer.controller.markdown, '普通剪贴板文字');
    expect(composer.controller.textController.text, '普通剪贴板文字');
    expect(clipboard.reads, 1);
    expect(find.byKey(const Key('popi-selected-assets')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _SettingsRepository extends DemoRepository {
  _SettingsRepository(super.storage);

  bool failNext = false;

  @override
  bool get isHarness => true;

  @override
  Future<DemoCapabilityCatalog> loadCapabilityCatalog({
    String? sessionId,
  }) async => const DemoCapabilityCatalog(
    skills: [
      DemoRuntimeCapability(
        id: demoStyleFilmSkillId,
        name: '制作风格短片',
        available: true,
      ),
    ],
  );

  @override
  Future<void> updateSession(
    String id,
    DemoSession Function(DemoSession) update,
  ) {
    if (failNext) {
      failNext = false;
      throw StateError('save failed');
    }
    return super.updateSession(id, update);
  }
}

class _ChatRepository extends DemoRepository {
  _ChatRepository(super.storage);

  final List<DemoStyleFilmInvocation?> invocations = [];
  bool fakeRunning = false;
  bool fakeCanStop = true;
  final uploaded = <DemoAsset>[];

  @override
  List<DemoAsset> get assets => [...super.assets, ...uploaded];

  @override
  bool get isHarness => true;

  @override
  bool isSessionRunning(String id) => fakeRunning;

  @override
  bool canStopCurrentHarnessRun(String id) => fakeCanStop;

  @override
  void validateMessageAttachments(List<String> assetIds) {}

  @override
  Future<DemoAsset> uploadFile(DemoUploadFile file) async {
    final asset = DemoAsset(
      id: 'clipboard-asset',
      title: file.name,
      kind: file.kind,
      cover: '',
      contentUrl:
          'http://127.0.0.1:3084/api_agent/v2/assets/clipboard-asset/content',
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
    );
    uploaded.add(asset);
    notifyListeners();
    return asset;
  }

  void setRun({required bool running, required bool canStop}) {
    fakeRunning = running;
    fakeCanStop = canStop;
    notifyListeners();
  }

  @override
  Future<void> resumeHarnessSession(String id) async {}

  @override
  Future<void> sendHarnessMessage(
    String sessionId, {
    required String clientRequestId,
    required String text,
    List<String> mediaIds = const [],
    List<String> contextRoleIds = const [],
    DemoStyleFilmInvocation? skillInvocation,
    VoidCallback? onAccepted,
  }) async {
    invocations.add(skillInvocation);
    if (skillInvocation != null) {
      final session = this.session(sessionId);
      final botId = session.botIdFor(session.activeMemberId);
      await updateStyleFilmDraft(sessionId, botId, null);
    }
    onAccepted?.call();
  }

  @override
  Future<DemoStyleFilmCatalog> loadStyleFilmCatalog({
    String? q,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async => const DemoStyleFilmCatalog(
    available: true,
    total: 1,
    page: 1,
    pageCount: 1,
    supports: DemoStyleFilmSupports(
      durations: [15],
      aspectRatios: ['9:16'],
      soundtracks: ['none'],
    ),
    list: [DemoStyleFilmStyle(id: 'impasto', nameZh: '油画厚涂', ready: true)],
  );
}

class _ClipboardService implements ClipboardImageService {
  int reads = 0;

  @override
  Future<List<ClipboardImagePayload>> readImagesFromUserPaste() async {
    reads += 1;
    return [
      ClipboardImagePayload(
        name: 'clipboard.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList(const [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
      ),
    ];
  }
}

class _EmptyClipboardService implements ClipboardImageService {
  int reads = 0;

  @override
  Future<List<ClipboardImagePayload>> readImagesFromUserPaste() async {
    reads += 1;
    return const [];
  }
}
