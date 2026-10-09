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
import '../domain/conversation_session.dart';
import '../domain/conversation_snapshot.dart';
import 'conversation_events.dart';

abstract class SessionRepository {
  Future<List<ConversationSession>> list(
    String userId, {
    CancelToken? cancelToken,
  });
  Future<ConversationSession> create(
    String userId,
    String title, {
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
    CancelToken? cancelToken,
  });
  Future<void> stop(String userId, String id, {CancelToken? cancelToken});
  Future<void> retry(String userId, String runId, {CancelToken? cancelToken});
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
  });
  Future<ConversationMedia> media(String id, {CancelToken? cancelToken});
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

  static List<ConversationSession> sorted(
    Iterable<ConversationSession> sessions,
  ) {
    final result = sessions.where((item) => !item.archived).toList();
    result.sort((a, b) {
      final pinned = (b.pinnedAt != null ? 1 : 0).compareTo(
        a.pinnedAt != null ? 1 : 0,
      );
      if (pinned != 0) return pinned;
      final date = (b.pinnedAt ?? b.updatedAt).compareTo(
        a.pinnedAt ?? a.updatedAt,
      );
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
  Future<List<ConversationSession>> list(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    final sessions = <String, ConversationSession>{};
    for (var page = 1; ; page++) {
      final response = await agent.sessionsPage(
        page: page,
        pageSize: 100,
        cancelToken: cancelToken,
      );
      final info = conversationMap(response['pageInfo']);
      final items = conversationMaps(response['list']);
      final pageCount = info['pageCount'];
      if (info['page'] != page ||
          info['pageSize'] != 100 ||
          pageCount is! int ||
          pageCount < 1 ||
          pageCount > 10000 ||
          info['total'] is! int ||
          (info['total'] as int) < 0 ||
          items.length > 100) {
        throw const FormatException('Invalid session pagination');
      }
      for (final item in items) {
        final session = ConversationSession.fromJson(item);
        sessions[session.id] = session;
      }
      if (page >= pageCount) return SessionRepository.sorted(sessions.values);
    }
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
      await agent.resolveSession(
        clientRequestId: input['clientRequestId'] as String,
        title: input['title'] as String,
        cancelToken: cancelToken,
      ),
    ),
  );

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
      await agent.updateSession(
        id,
        clientRequestId: input['clientRequestId'] as String,
        expectedRevision: input['expectedRevision'] as int,
        title: input['title'] as String?,
        pinned: input['pinned'] as bool?,
        archived: input['archived'] as bool?,
        cancelToken: cancelToken,
      ),
    ),
    prepare: () async => {
      'expectedRevision': (await snapshot(
        id,
        cancelToken: cancelToken,
      )).session.revision,
    },
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
    CancelToken? cancelToken,
  }) async {
    if (text.trim().isEmpty || text.length > 20000) {
      throw ArgumentError.value(text, 'text');
    }
    await _command(
      userId,
      'send:$id',
      {'text': text, 'mediaIds': mediaIds},
      (input) => agent.sendSessionMessage(
        id,
        clientRequestId: input['clientRequestId'] as String,
        text: input['text'] as String,
        mediaIds: (input['mediaIds'] as List).cast<String>(),
        inputRefs: const [],
        cancelToken: cancelToken,
      ),
    );
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
  Future<ConversationMedia> media(String id, {CancelToken? cancelToken}) async {
    final value = await business.studioMedia(id, cancelToken: cancelToken);
    return ConversationMedia(
      id: value['id'].toString(),
      kind: value['kind'] as String,
      url: Uri.parse(
        business.mediaBaseUrl,
      ).resolve(value['url'] as String).toString(),
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
    if (!card.confirmationAvailable || !card.allowedActions.contains(action)) {
      throw StateError('Confirmation expired');
    }
    if (action == 'confirm' && card.data['kind'] == 'generation') {
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
  }

  Future<T> _command<T>(
    String userId,
    String operation,
    Map<String, Object?> input,
    Future<T> Function(Map<String, Object?>) run, {
    Future<Map<String, Object?>> Function()? prepare,
  }) async {
    final preferences = storage();
    final key =
        'agent.command.$userId.${sha256.convert(utf8.encode(_canonical([operation, input])))}';
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

String _canonical(Object? value) {
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}
