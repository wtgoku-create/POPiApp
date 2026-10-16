import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/agent_api_exception.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/network/network_api.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/app_url.dart';
import '../../assets/domain/library_work.dart';
import '../../role_guide/domain/home_creation.dart';
import '../../role_guide/domain/session_media_preferences.dart';
import '../domain/conversation_generation.dart';
import '../domain/conversation_session.dart';
import '../../../shared/type/list_page.dart';
import '../domain/conversation_snapshot.dart';
import 'conversation_events.dart';

abstract class SessionRepository {
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  });
  Future<ConversationSession> create(
    String userId,
    String title, {
    CancelToken? cancelToken,
  });
  Future<ConversationSession> resolveAccountSession(
    String userId,
    String accountId,
    String title, {
    CancelToken? cancelToken,
  });
  Future<ConversationSession> createFromContent(
    String userId, {
    CancelToken? cancelToken,
  });
  Future<ConversationSession> update(
    String userId,
    String id, {
    String? title,
    bool? pinned,
    bool? archived,
    CancelToken? cancelToken,
  });
  Future<ConversationSnapshot> snapshot(String id, {CancelToken? cancelToken});
  Stream<ConversationEvent> events(
    String id,
    int afterSeq,
    CancelToken cancelToken, {
    void Function()? onConnected,
  });
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  });
  Future<void> stop(String userId, String id, {CancelToken? cancelToken});
  Future<void> retry(String userId, String runId, {CancelToken? cancelToken});
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  });
  Future<ConversationMedia> media(String id, {CancelToken? cancelToken});
  Future<String> importLibraryWork(
    String userId,
    LibraryWork work, {
    CancelToken? cancelToken,
  });
  Future<void> answer(
    String id,
    ConversationBlock question,
    String action,
    Map<String, Object?> answer, {
    CancelToken? cancelToken,
  });
  Future<void> confirm(
    String userId,
    String id,
    ConversationBlock card,
    String action, {
    CancelToken? cancelToken,
  });
  Future<void> topicAction(
    String userId,
    String sessionId,
    ConversationBlock topic, {
    bool refresh = false,
    CancelToken? cancelToken,
  });
  Future<ConversationGenerationOptions> generationOptions(
    String userId,
    String sessionId,
    ConversationBlock card, {
    CancelToken? cancelToken,
  });
  Future<num> estimateGeneration(
    String mediaType,
    HomeConfig config, {
    CancelToken? cancelToken,
  });
  Future<ListPage<ConversationRoleTemplate>> roleTemplates({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  });
  Future<void> confirmGeneration(
    String userId,
    String sessionId,
    ConversationBlock card,
    ConversationGenerationSelection selection, {
    CancelToken? cancelToken,
  });
  Future<Map<String, Object?>> taskCapabilities(
    String id, {
    CancelToken? cancelToken,
  });
  Future<void> controlTask(
    String userId,
    ConversationBlock task,
    String action, {
    Map<String, Object?>? capabilities,
    CancelToken? cancelToken,
  });
  Future<void> respondProposal(
    String userId,
    ConversationBlock task,
    Map<String, Object?> proposal,
    String action, {
    CancelToken? cancelToken,
  });

  static List<ConversationSession> sorted(
    Iterable<ConversationSession> sessions,
  ) {
    final result = sessions.where((item) => !item.archived).toList();
    result.sort((a, b) {
      final pinned = (b.pinnedAt != null ? 1 : 0).compareTo(
        a.pinnedAt != null ? 1 : 0,
      );
      if (pinned != 0) return pinned;
      final date = b.activityAt.compareTo(a.activityAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
    return List.unmodifiable(result);
  }
}

class ConversationMedia {
  const ConversationMedia({
    required this.id,
    required this.kind,
    required this.url,
  });
  final String id;
  final String kind;
  final String url;
}

/// Shares Web's v2 contracts and persists uncertain commands by account.
class ApiSessionRepository extends SessionRepository {
  ApiSessionRepository(this.agent, this.business, this.storage);
  final NetworkAgentApi agent;
  final NetworkApi business;
  final PreferencesStorage Function() storage;

  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid session page');
    }
    final response = await agent.sessionsPage(
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    final info = conversationMap(response['pageInfo']);
    final items = conversationMaps(response['list']);
    final pageCount = info['pageCount'];
    if (info['page'] != page ||
        info['pageSize'] != pageSize ||
        pageCount is! int ||
        pageCount < 1 ||
        pageCount > 10000 ||
        info['total'] is! int ||
        (info['total'] as int) < 0 ||
        items.length > pageSize ||
        (items.isEmpty && page < pageCount)) {
      throw const FormatException('Invalid session pagination');
    }
    final sessions = <String, ConversationSession>{};
    for (final item in items) {
      final session = ConversationSession.fromJson(item);
      sessions[session.id] = session;
    }
    return ConversationSessionPage(
      items: List.unmodifiable(sessions.values.where((item) => !item.archived)),
      page: page,
      pageCount: pageCount,
    );
  }

  String _title(String value) {
    final title = value.trim();
    if (title.isEmpty || title.runes.length > 200) {
      throw ArgumentError.value(value, 'title');
    }
    return title;
  }

  @override
  Future<ConversationSession> create(
    String userId,
    String title, {
    CancelToken? cancelToken,
  }) => _command(
    userId,
    'create',
    {'title': _title(title)},
    (input) async => ConversationSession.fromJson(
      await agent.createSession(
        clientRequestId: input['clientRequestId'] as String,
        title: input['title'] as String,
        cancelToken: cancelToken,
      ),
    ),
  );

  @override
  Future<ConversationSession> resolveAccountSession(
    String userId,
    String accountId,
    String title, {
    CancelToken? cancelToken,
  }) async {
    try {
      return ConversationSession.fromJson(
        await agent.sessionByAccount(accountId, cancelToken: cancelToken),
      );
    } on AgentApiException catch (error) {
      if (error.statusCode != 404 ||
          error.code != 'ACCOUNT_SESSION_NOT_FOUND') {
        rethrow;
      }
    }
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    // Retain the account-scoped command across timeouts and application restarts.
    return _command(
      userId,
      'create-account:$accountId',
      {'accountId': accountId, 'title': _title(title)},
      (input) async {
        try {
          return ConversationSession.fromJson(
            await agent.createSession(
              clientRequestId: input['clientRequestId'] as String,
              accountId: input['accountId'] as String,
              title: input['title'] as String,
              cancelToken: cancelToken,
            ),
          );
        } on AgentApiException catch (error) {
          if (error.statusCode != 409 ||
              error.code != 'ACCOUNT_SESSION_EXISTS') {
            rethrow;
          }
          // Another client may have bound the account after our lookup.
          return ConversationSession.fromJson(
            await agent.sessionByAccount(accountId, cancelToken: cancelToken),
          );
        }
      },
    );
  }

  @override
  Future<ConversationSession> createFromContent(
    String userId, {
    CancelToken? cancelToken,
  }) => _command(userId, 'content-entry', const {}, (input) async {
    final session = ConversationSession.fromJson(
      await agent.createContentSession(
        clientRequestId: input['clientRequestId'] as String,
        cancelToken: cancelToken,
      ),
    );
    if (session.bindingStatus != 'ready') {
      throw const FormatException('Content session binding is not ready');
    }
    return session;
  });

  @override
  Future<ConversationSession> update(
    String userId,
    String id, {
    String? title,
    bool? pinned,
    bool? archived,
    CancelToken? cancelToken,
  }) => _command(
    userId,
    'update:$id',
    {
      if (title != null) 'title': _title(title),
      if (pinned != null) 'pinned': pinned,
      if (archived != null) 'archived': archived,
    },
    (input) async => ConversationSession.fromJson(
      input['archived'] == true &&
              input['title'] == null &&
              input['pinned'] == null
          ? await agent.archiveSession(id, cancelToken: cancelToken)
          : await agent.updateSession(
              id,
              clientRequestId: input['clientRequestId'] as String,
              title: input['title'] as String?,
              pinned: input['pinned'] as bool?,
              archived: input['archived'] as bool?,
              cancelToken: cancelToken,
            ),
    ),
  );

  @override
  Future<ConversationSnapshot> snapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => ConversationSnapshot.fromJson(
    await agent.sessionSnapshot(id, cancelToken: cancelToken),
  );

  @override
  Stream<ConversationEvent> events(
    String id,
    int afterSeq,
    CancelToken cancelToken, {
    void Function()? onConnected,
  }) async* {
    final body = await agent.openSessionEvents(
      id,
      afterSeq: afterSeq,
      cancelToken: cancelToken,
    );
    onConnected?.call();
    yield* decodeConversationEvents(body.stream);
  }

  @override
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  }) async {
    if (text.trim().isEmpty || text.length > 20000) {
      throw ArgumentError.value(text, 'text');
    }
    final cast = roleIds.map(_roleId).toList();
    if (cast.length > 5 || cast.toSet().length != cast.length) {
      throw ArgumentError.value(roleIds, 'roleIds');
    }
    await _command(
      userId,
      'send:$id',
      {
        'text': text,
        'mediaIds': mediaIds,
        if (cast.isNotEmpty) 'roleIds': cast,
      },
      (input) async {
        // Save the cast without starting a reply; the message starts one run.
        if (input['roleIds'] is List) {
          await agent.updateSessionCast(id, {
            'clientRequestId': input['clientRequestId'],
            'roleIds': input['roleIds'],
            'reply': false,
          }, cancelToken: cancelToken);
        }
        return agent.sendSessionMessage(
          id,
          clientRequestId: input['clientRequestId'] as String,
          text: input['text'] as String,
          mediaIds: (input['mediaIds'] as List).cast<String>(),
          cancelToken: cancelToken,
        );
      },
    );
  }

  int _roleId(String value) {
    final id = int.tryParse(value);
    if (id == null || id <= 0 || id > 9007199254740991) {
      throw ArgumentError.value(value, 'roleId');
    }
    return id;
  }

  @override
  Future<void> stop(
    String userId,
    String id, {
    CancelToken? cancelToken,
  }) async {
    await _command(
      userId,
      'stop:$id',
      const {},
      (input) => agent.stopSession(
        id,
        clientRequestId: input['clientRequestId'] as String,
        cancelToken: cancelToken,
      ),
    );
  }

  @override
  Future<void> retry(
    String userId,
    String runId, {
    CancelToken? cancelToken,
  }) async {
    await _command(
      userId,
      'retry:$runId',
      const {},
      (input) => agent.retryRun(
        runId,
        clientRequestId: input['clientRequestId'] as String,
        cancelToken: cancelToken,
      ),
    );
  }

  @override
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final input = {
      'name': name,
      'mime':
          lookupMimeType(name, headerBytes: bytes) ??
          'application/octet-stream',
      'size': bytes.length,
      'hash': sha256.convert(bytes).toString(),
    };
    // 发送结果不确定时再次发送必须沿用相同 mediaIds，否则幂等键会改变。
    final mediaKey =
        'agent.media.$userId.${sha256.convert(utf8.encode(_canonical(input)))}';
    final savedMediaId = storage().getString(mediaKey);
    if (savedMediaId != null) return savedMediaId;
    final lease = await _command(
      userId,
      'upload',
      input,
      (command) =>
          business.createStudioUpload(command, cancelToken: cancelToken),
    );
    await business.uploadStudioBytes(
      lease['uploadUrl'] as String,
      conversationMap(lease['uploadHeaders']),
      bytes,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    final uploadId = conversationMap(lease['upload'])['id'] as String;
    final completed = await _command(
      userId,
      'upload-complete:$uploadId',
      const {},
      (command) => business.completeStudioUpload(
        uploadId,
        command['clientRequestId'] as String,
        cancelToken: cancelToken,
      ),
    );
    final mediaId = completed['mediaId'] as String;
    await storage().setString(mediaKey, mediaId);
    return mediaId;
  }

  @override
  Future<String> importLibraryWork(
    String userId,
    LibraryWork work, {
    CancelToken? cancelToken,
  }) async {
    final source = work.isVideo ? work.videoUrl : work.previewUrl;
    final key =
        'agent.library-media.$userId.${sha256.convert(utf8.encode(_canonical({'assetId': work.id, 'source': source})))}';
    final saved = storage().getString(key);
    if (saved != null) return saved;
    // Legacy work IDs belong to ani_asset, not the Agent's registered media.
    final bytes = await business.readLibraryMedia(
      source,
      cancelToken: cancelToken,
    );
    final name = Uri.parse(source).pathSegments.lastOrNull ?? '';
    final mediaId = await upload(
      userId,
      name.contains('.') ? name : '${work.id}.${work.isVideo ? 'mp4' : 'png'}',
      bytes,
      cancelToken: cancelToken,
    );
    await storage().setString(key, mediaId);
    return mediaId;
  }

  @override
  Future<ConversationMedia> media(String id, {CancelToken? cancelToken}) async {
    final value = await business.studioMedia(id, cancelToken: cancelToken);
    return ConversationMedia(
      id: value['id'].toString(),
      kind: value['kind'] as String,
      url: AppUrl.resolve(
        value['url'] as String,
        baseUrl: business.mediaBaseUrl,
      ),
    );
  }

  @override
  Future<void> answer(
    String id,
    ConversationBlock question,
    String action,
    Map<String, Object?> answer, {
    CancelToken? cancelToken,
  }) async {
    await agent.respondQuestion(
      id,
      question.id,
      revision: question.revision,
      action: action,
      answer: answer,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<void> confirm(
    String userId,
    String id,
    ConversationBlock card,
    String action, {
    CancelToken? cancelToken,
  }) async {
    if (card.isHomePlan) {
      if (card.status != 'ready' || action != 'cancel') {
        throw StateError('Action unavailable');
      }
      await agent.respondHomePlan(
        id,
        card.id,
        'cancel',
        const {},
        cancelToken: cancelToken,
      );
      await _clearGenerationRecovery(userId, id, card.id);
      return;
    }
    if (!card.confirmationAvailable || !card.allowedActions.contains(action)) {
      throw StateError('Confirmation expired');
    }
    if (action == 'confirm' && card.objectKind == 'generation') {
      if (card.roleImage != null) {
        throw StateError('Generation selection required');
      }
      final request = card.request;
      if (request == null || request['method'] != 'POST') {
        throw const FormatException('Missing generation request');
      }
      await business.confirmStudioGeneration(
        request['path'] as String,
        conversationMap(request['body']),
        cancelToken: cancelToken,
      );
    }
    await _command(
      userId,
      'confirm:$id:${card.id}',
      {'revision': card.revision, 'action': action},
      (input) => agent.respondConfirmation(
        id,
        card.id,
        clientRequestId: input['clientRequestId'] as String,
        revision: input['revision'] as int,
        action: input['action'] as String,
        cancelToken: cancelToken,
      ),
    );
    if (action == 'cancel') {
      await _clearGenerationRecovery(userId, id, card.id);
    }
  }

  @override
  Future<void> topicAction(
    String userId,
    String sessionId,
    ConversationBlock topic, {
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    if (topic.scopeKind != 'creation' ||
        topic.scopeId == null ||
        topic.referenceId.isEmpty ||
        topic.action == 'selected') {
      throw StateError('Topic unavailable');
    }
    final creationId = topic.scopeId!;
    await _command(
      userId,
      'topic:$sessionId:$creationId:${refresh ? 'refresh' : topic.referenceId}',
      {if (refresh) 'mode': 'recommend' else 'topicId': topic.referenceId},
      (input) async {
        if (refresh) {
          await agent.recommendHomeTopics(
            sessionId,
            input,
            cancelToken: cancelToken,
          );
        } else {
          await agent.selectHomeTopic(
            sessionId,
            input,
            cancelToken: cancelToken,
          );
        }
      },
    );
  }

  String _selectionKey(String userId, String sessionId, String id) =>
      'agent.generation.$userId.$sessionId.$id';

  Future<void> _clearGenerationRecovery(
    String userId,
    String sessionId,
    String id,
  ) async {
    final key = _selectionKey(userId, sessionId, id);
    final saved = storage().getString(key);
    if (saved != null) {
      await storage().remove(
        _commandKey(
          userId,
          'generation:$sessionId:$id',
          conversationMap(jsonDecode(saved)),
        ),
      );
    }
    await storage().remove(key);
    await storage().remove('$key.configuration');
    await storage().remove('$key.preferencesChanged');
  }

  @override
  Future<ConversationGenerationOptions> generationOptions(
    String userId,
    String sessionId,
    ConversationBlock card, {
    CancelToken? cancelToken,
  }) async {
    final models =
        conversationMaps(
              (await business.mediaModels(
                mediaType: card.isHomePlan ? 'video' : card.mediaType,
                cancelToken: cancelToken,
              ))['list'],
            )
            .map(HomeModel.fromJson)
            .where(
              (model) =>
                  model.available &&
                  model.mediaType ==
                      (card.isHomePlan ? 'video' : card.mediaType),
            )
            .toList();
    final preferences = SessionMediaPreferences.fromJson(
      await business.sessionMediaPreferences(
        sessionId,
        cancelToken: cancelToken,
      ),
    );
    final key = _selectionKey(userId, sessionId, card.id);
    final saved = storage().getString(key);
    var recovery = saved == null
        ? null
        : ConversationGenerationSelection.fromJson(
            conversationMap(jsonDecode(saved)),
          );
    // 配置已固定时只能更新偏好版本，不能给同一卡片换一套生成输入。
    if (recovery != null &&
        storage().getString('$key.preferencesChanged') != null) {
      final preferred = card.mediaType == 'image'
          ? preferences.image
          : preferences.video;
      if (preferred != null &&
          _canonical(preferred.toJson()) ==
              _canonical(recovery.config.toJson())) {
        recovery = ConversationGenerationSelection.fromJson({
          ...recovery.toJson(),
          'mediaPreferencesRevision': preferences.revision,
        });
        await storage().setString(key, jsonEncode(recovery.toJson()));
        await storage().remove('$key.preferencesChanged');
      }
    }
    return ConversationGenerationOptions(
      models: models,
      preferences: preferences,
      recovery: recovery,
    );
  }

  @override
  Future<num> estimateGeneration(
    String mediaType,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) async {
    final points = (await business.estimateStudioGeneration(
      mediaType,
      config.toJson(),
      cancelToken: cancelToken,
    ))['estimatedPoints'];
    if (points is! num || !points.isFinite || points < 0) {
      throw const FormatException('Invalid estimate');
    }
    return points;
  }

  @override
  Future<ListPage<ConversationRoleTemplate>> roleTemplates({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final result = await business.roleTemplatesPage(
      page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    return ListPage.fromJson(
      result,
      page: page,
      pageSize: pageSize,
      parse: ConversationRoleTemplate.fromJson,
    );
  }

  /// 配置、业务授权、Agent 回执共用同一恢复输入，任何一次超时都可继续。
  @override
  Future<void> confirmGeneration(
    String userId,
    String sessionId,
    ConversationBlock card,
    ConversationGenerationSelection selection, {
    CancelToken? cancelToken,
  }) async {
    if (card.isHomePlan
        ? card.status != 'ready'
        : !card.confirmationAvailable ||
              !card.allowedActions.contains('confirm')) {
      throw StateError('Confirmation unavailable');
    }
    if (!selection.estimatedPoints.isFinite || selection.estimatedPoints < 0) {
      throw const FormatException('Invalid estimate');
    }
    final key = _selectionKey(userId, sessionId, card.id);
    final saved = storage().getString(key);
    final fixed = saved == null
        ? selection
        : ConversationGenerationSelection.fromJson(
            conversationMap(jsonDecode(saved)),
          );
    await storage().setString(key, jsonEncode(fixed.toJson()));
    var configurationCompleted = false;
    var authorizationCompleted = false;
    try {
      await _command(
        userId,
        'generation:$sessionId:${card.id}',
        fixed.toJson(),
        (input) async {
          if (card.isHomePlan) {
            await agent.respondHomePlan(sessionId, card.id, 'generate', {
              'clientRequestId': input['clientRequestId'],
              'config': fixed.config.toJson(),
            }, cancelToken: cancelToken);
            return;
          }
          var request = card.request;
          if (card.roleImage != null) {
            final configurationKey = '$key.configuration';
            final configurationId =
                storage().getString(configurationKey) ?? const Uuid().v4();
            await storage().setString(configurationKey, configurationId);
            final configured = await agent.configureRoleImage(
              sessionId,
              card.id,
              {
                'clientRequestId': configurationId,
                ...fixed.roleImageConfiguration,
              },
              cancelToken: cancelToken,
            );
            configurationCompleted = true;
            request = conversationMap(configured['request']);
          }
          if (request == null || request['method'] != 'POST') {
            throw const FormatException('Missing generation request');
          }
          final body = conversationMap(request['body']);
          var generation = conversationMap(body['input']);
          final legacyThreeView = card.isThreeView && card.roleImage == null;
          if (legacyThreeView) {
            final preview = await agent.previewGenerationTemplate(
              sessionId,
              card.id,
              fixed.roleTemplateId,
              cancelToken: cancelToken,
            );
            generation = conversationMap(preview['generation']);
          }
          final item = conversationMap(generation['item']);
          await business.confirmStudioGeneration(request['path'] as String, {
            ...body,
            'input': {
              ...generation,
              'item': {
                ...item,
                ...fixed.config.toJson(),
                if (legacyThreeView)
                  'references': [
                    for (final ref in conversationMaps(item['references']))
                      if (ref['purpose'] == 'style') ref,
                    if (fixed.referenceMediaId != null)
                      {
                        'mediaId': fixed.referenceMediaId,
                        'purpose': 'reference',
                      },
                  ],
              },
            },
            'maxEstimatedPoints': fixed.estimatedPoints,
            'mediaPreferencesRevision': fixed.mediaPreferencesRevision,
          }, cancelToken: cancelToken);
          authorizationCompleted = true;
          await agent.respondConfirmation(
            sessionId,
            card.id,
            clientRequestId: input['clientRequestId'] as String,
            revision: card.revision,
            action: 'confirm',
            generationConfig: {
              ...fixed.config.toJson(),
              if (legacyThreeView) ...{
                'referenceMediaId': fixed.referenceMediaId,
                'roleTemplateId': fixed.roleTemplateId,
              },
            },
            cancelToken: cancelToken,
          );
        },
      );
      await _clearGenerationRecovery(userId, sessionId, card.id);
    } catch (error) {
      if (error is AgentApiException &&
          error.code == 'MEDIA_PREFERENCES_CHANGED') {
        if (card.roleImage == null) {
          await _clearGenerationRecovery(userId, sessionId, card.id);
        } else {
          await storage().setString('$key.preferencesChanged', '1');
        }
      } else if (!configurationCompleted &&
          !authorizationCompleted &&
          error is AgentApiException &&
          (error.statusCode ?? 500) < 500 &&
          !error.retryable &&
          !['COMMAND_PENDING', 'CONFIRMATION_PENDING'].contains(error.code)) {
        await _clearGenerationRecovery(userId, sessionId, card.id);
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>> taskCapabilities(
    String id, {
    CancelToken? cancelToken,
  }) => agent.taskCapabilities(id, cancelToken: cancelToken);

  @override
  Future<void> controlTask(
    String userId,
    ConversationBlock task,
    String action, {
    Map<String, Object?>? capabilities,
    CancelToken? cancelToken,
  }) async {
    final home = task.action == 'home';
    final allowed = home
        ? task.allowedActions
        : ((capabilities?['allowedActions'] as List?) ?? [])
              .whereType<String>()
              .toList();
    if (!allowed.contains(action) &&
        !(home &&
            action == 'confirm-video' &&
            task.status == 'awaiting_confirmation' &&
            task.data['confirmationPending'] == true &&
            task.data['intent'] != 'cancel')) {
      throw StateError('Action unavailable');
    }
    await _command(
      userId,
      'task:${task.id}:$action',
      {
        if (!home) 'revision': capabilities?['revision'],
        if (action != 'confirm-video') 'action': action,
      },
      (input) async {
        if (home) {
          await agent.controlHomeTask(
            task.id,
            input,
            confirmVideo: action == 'confirm-video',
            cancelToken: cancelToken,
          );
        } else {
          await agent.controlTask(task.id, action, {
            'clientRequestId': input['clientRequestId'],
            'revision': input['revision'],
          }, cancelToken: cancelToken);
        }
      },
    );
  }

  @override
  Future<void> respondProposal(
    String userId,
    ConversationBlock task,
    Map<String, Object?> proposal,
    String action, {
    CancelToken? cancelToken,
  }) async {
    if (task.status != 'waiting_user' ||
        proposal['status'] != 'ready' ||
        action == 'confirm' && proposal['executionAvailable'] == false) {
      throw StateError('Proposal unavailable');
    }
    final quote = proposal['quote'];
    await _command(
      userId,
      'proposal:${proposal['id']}:$action',
      {
        'revision': proposal['revision'],
        if (action == 'confirm') ...{
          'planHash': proposal['planHash'],
          if (task.data['executionPolicy'] != 'estimate_only' && quote is Map)
            'quoteId': quote['id'],
        },
      },
      (input) async {
        await agent.respondProposal(
          proposal['id'] as String,
          action,
          input,
          cancelToken: cancelToken,
        );
      },
    );
  }

  Future<T> _command<T>(
    String userId,
    String operation,
    Map<String, Object?> input,
    Future<T> Function(Map<String, Object?>) run, {
    Future<Map<String, Object?>> Function()? prepare,
  }) async {
    final preferences = storage();
    final key = _commandKey(userId, operation, input);
    final saved = preferences.getString(key);
    Map<String, Object?> command;
    if (saved == null) {
      // 网络超时并不意味着服务端未执行。持久化完整输入，重试复用 ID 和 revision。
      command = {
        ...input,
        if (prepare != null) ...await prepare(),
        'clientRequestId': const Uuid().v4(),
      };
      await preferences.setString(key, jsonEncode(command));
    } else {
      command = conversationMap(jsonDecode(saved));
    }
    try {
      final result = await run(command);
      await preferences.remove(key);
      return result;
    } on AgentApiException catch (error) {
      // 只有明确拒绝的命令才能丢弃；5xx、待执行和传输失败都保留恢复信息。
      if ((error.statusCode ?? 500) < 500 &&
          !error.retryable &&
          error.code != 'COMMAND_PENDING') {
        await preferences.remove(key);
      }
      rethrow;
    }
  }
}

String _commandKey(
  String userId,
  String operation,
  Map<String, Object?> input,
) =>
    'agent.command.$userId.${sha256.convert(utf8.encode(_canonical([operation, input])))}';

String _canonical(Object? value) {
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}
