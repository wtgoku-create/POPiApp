import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../domain/activity.dart';

/// Mirrors the web activity list and activation contracts.
class ActivityRepository {
  const ActivityRepository(this.api);

  final NetworkApi api;

  Future<ActivityCatalog> fetchCatalog({DateTime? now}) async {
    final data = await api.activities();
    final raw = data['list'];
    if (raw is! List) throw const ApiException();
    final timestamp = now ?? DateTime.now();
    final activities = raw
        .whereType<Map>()
        .map((item) => _activity(Map<String, Object?>.from(item)))
        .where((item) => item.id > 0 && item.isActiveAt(timestamp))
        .toList();
    final memberLabels = <int, String>{};
    if (activities.any((item) => item.memberLevels.isNotEmpty)) {
      try {
        final members = (await api.memberLevels())['list'];
        if (members is List) {
          for (final member in members.whereType<Map>()) {
            final label = _text(member['memberName']);
            if (label.isNotEmpty) {
              memberLabels[_integer(member['memberLevel'])] = label;
            }
          }
        }
      } catch (_) {
        // Eligibility uses numeric levels even when display names are unavailable.
      }
    }
    return ActivityCatalog(activities: activities, memberLabels: memberLabels);
  }

  Future<String?> redeem(
    Activity activity,
    String code, {
    required int memberLevel,
  }) async {
    final value = code.trim();
    if (value.isEmpty || value.length > 64) {
      throw ArgumentError.value(code, 'code');
    }
    if (!activity.isActiveAt(DateTime.now()) ||
        !activity.allowsMemberLevel(memberLevel)) {
      throw const ApiException();
    }
    final data = await api.activateActivityCode(value);
    return activity.isBookCard ? _qrUrl(data['url']) : null;
  }

  Activity _activity(Map<String, Object?> json) {
    final levels = json['memberLevels'];
    return Activity(
      id: _integer(json['id']),
      name: _text(json['name']),
      type: _text(json['type']),
      description: _text(
        json['desp'],
      ).replaceAll(RegExp(r'\\r\\n|\\n|\\r|\r\n|\r'), '\n'),
      coverUrl: _mediaUrl(json['cover']),
      tags: _tags(json['tags']),
      memberLevels: levels is List
          ? levels.map(_integer).toSet().toList()
          : const [],
      status: _integer(json['status']),
      startsAt: DateTime.tryParse(_text(json['startTime'])),
      endsAt: DateTime.tryParse(_text(json['endTime'])),
    );
  }

  String _mediaUrl(Object? value) {
    final text = _text(value);
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null) return '';
    final resolved = Uri.parse(api.mediaBaseUrl).resolveUri(uri);
    return _isHttp(resolved) ? resolved.toString() : '';
  }
}

List<ActivityTag> _tags(Object? value) {
  if (value is! String || value.isEmpty) return const [];
  try {
    final parsed = jsonDecode(value);
    if (parsed is! List) return const [];
    return [
      for (final tag in parsed.whereType<Map>())
        if (_text(tag['label']).isNotEmpty)
          ActivityTag(
            label: _text(tag['label']),
            background: _color(tag['bgColor']),
            foreground: _color(tag['textColor']),
          ),
    ];
  } on FormatException {
    return const [];
  }
}

int? _color(Object? value) {
  final text = _text(value);
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(text)) return null;
  return 0xFF000000 | int.parse(text.substring(1), radix: 16);
}

String? _qrUrl(Object? value) {
  final text = _text(value);
  final match = RegExp(
    r'^\[[^\]]*\]\((https?://[^)]+)\)$',
    caseSensitive: false,
  ).firstMatch(text);
  final uri = Uri.tryParse(match?.group(1)?.trim() ?? text);
  return uri != null && _isHttp(uri) ? uri.toString() : null;
}

bool _isHttp(Uri uri) =>
    (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

String _text(Object? value) => value?.toString().trim() ?? '';
