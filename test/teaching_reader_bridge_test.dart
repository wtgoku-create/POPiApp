import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/teaching/data/teaching_reader_bridge.dart';
import 'package:popi_ai_app/features/teaching/domain/teaching.dart';

void main() {
  final bridge = TeachingReaderBridge(
    url: Uri.parse('https://popi.test/teaching/reader'),
    session: 'session',
  );

  test('binds navigation to the configured reader and load session', () {
    expect(
      bridge.acceptsNavigation(bridge.url.replace(fragment: 'heading')),
      isTrue,
    );
    for (final url in [
      'https://popi.test/teaching/reader?bridgeSession=old',
      'https://other.test/teaching/reader?bridgeSession=session',
      'https://popi.test/profile?bridgeSession=session',
      'https://user:pass@popi.test/teaching/reader?bridgeSession=session',
      'javascript:alert(1)',
    ]) {
      expect(bridge.acceptsNavigation(Uri.parse(url)), isFalse);
    }
  });

  test('ignores malformed, stale, unsupported and unsafe messages', () {
    for (final message in [
      'bad',
      '[]',
      '{"version":1,"session":"old","type":"ready"}',
      '{"version":2,"session":"session","type":"ready"}',
    ]) {
      expect(bridge.parseEvent(message), isNull);
    }
    for (final url in [
      'javascript:alert(1)',
      'file:///private/file',
      'data:text/html,test',
    ]) {
      expect(
        bridge.parseEvent(
          jsonEncode({
            'version': 1,
            'session': 'session',
            'type': 'openLink',
            'url': url,
          }),
        ),
        isNull,
      );
    }
    final event = bridge.parseEvent(
      jsonEncode({
        'version': 1,
        'session': 'session',
        'type': 'rendered',
        'requestId': 'request',
        'catalog': [
          {'id': 'h1', 'title': '标题', 'level': 1},
          {'id': 'h3', 'title': '三级', 'level': 3},
          {'id': false, 'level': 2},
        ],
      }),
    )!;
    expect(event.requestId, 'request');
    expect(event.catalog.single.id, 'h1');
  });

  test(
    'serializes hostile text as data and sends an explicit permission result',
    () {
      const content = '引号";window.hacked=true;//\n</script> ${r'${token}'}';
      final script = bridge.renderScript(
        requestId: 'request',
        document: const TeachingDocument(id: 1, contentHtml: content),
        course: const TeachingCourse(id: 2, name: content, description: '简介'),
        mediaBaseUrl: 'https://api.test',
        requiredMemberLevelName: 'Plus',
        dark: true,
        locale: 'en',
        textScale: 1.5,
      );
      final literal = script.substring(
        'window.PopiTeachingReader.receive(JSON.parse('.length,
        script.length - 3,
      );
      final payload = jsonDecode(jsonDecode(literal) as String) as Map;
      expect(payload['session'], 'session');
      final data = payload['payload'] as Map;
      expect((data['document'] as Map)['contentHtml'], content);
      expect((data['document'] as Map)['canViewPaidContent'], isFalse);
      expect((data['course'] as Map)['description'], '简介');
      expect(data['theme'], 'dark');
      expect(data['locale'], 'en-US');
      expect(data['textScale'], 1.5);
      expect((data['document'] as Map).containsKey('token'), isFalse);
    },
  );
}
