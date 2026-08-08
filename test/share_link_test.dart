import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fl_xray/src/core/share_link.dart';

Map<String, dynamic> _outbound(String encoded) =>
    jsonDecode(encoded) as Map<String, dynamic>;

void main() {
  const parser = ShareLinkParser();

  test('parses a reality vless link', () {
    final profile = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@example.com:443'
      '?type=tcp&security=reality&pbk=key&sid=ab&sni=www.microsoft.com&flow=xtls-rprx-vision'
      '#Amsterdam',
    );

    expect(profile.name, 'Amsterdam');
    expect(profile.protocol, 'vless');
    expect(profile.endpoint, 'example.com:443');
    expect(profile.security, 'reality');

    final outbound = _outbound(profile.outbound);
    final user = (((outbound['settings'] as Map)['vnext'] as List).first
        as Map)['users'] as List;
    expect((user.first as Map)['flow'], 'xtls-rprx-vision');
    final reality =
        (outbound['streamSettings'] as Map)['realitySettings'] as Map;
    expect(reality['publicKey'], 'key');
    expect(reality['serverName'], 'www.microsoft.com');
  });

  test('parses a websocket vmess link', () {
    final payload = base64.encode(
      utf8.encode(
        jsonEncode({
          'v': '2',
          'ps': 'Tokyo',
          'add': '1.2.3.4',
          'port': '8080',
          'id': 'uuid',
          'aid': '0',
          'net': 'ws',
          'host': 'cdn.example.com',
          'path': '/ray',
          'tls': 'tls',
        }),
      ),
    );

    final profile = parser.parse('vmess://$payload');

    expect(profile.name, 'Tokyo');
    expect(profile.port, 8080);
    expect(profile.network, 'ws');

    final stream = _outbound(profile.outbound)['streamSettings'] as Map;
    expect((stream['wsSettings'] as Map)['path'], '/ray');
    expect(((stream['wsSettings'] as Map)['headers'] as Map)['Host'],
        'cdn.example.com');
    expect((stream['tlsSettings'] as Map)['serverName'], 'cdn.example.com');
  });

  test('parses trojan and base64 shadowsocks links', () {
    final trojan = parser.parse('trojan://secret@host.net:443?sni=host.net#T');
    final trojanServer =
        ((_outbound(trojan.outbound)['settings'] as Map)['servers'] as List).first
            as Map;
    expect(trojanServer['password'], 'secret');

    final credentials = base64.encode(utf8.encode('aes-256-gcm:pass'));
    final ss = parser.parse('ss://$credentials@1.1.1.1:8388#SS');
    final ssServer =
        ((_outbound(ss.outbound)['settings'] as Map)['servers'] as List).first as Map;
    expect(ss.name, 'SS');
    expect(ssServer['method'], 'aes-256-gcm');
    expect(ssServer['password'], 'pass');
  });

  test('parses a base64 subscription body and skips broken lines', () {
    final body = base64.encode(
      utf8.encode(
        'vless://uuid@a.com:443#A\n'
        'not-a-link\n'
        'trojan://pw@b.com:443#B\n',
      ),
    );

    final profiles = parser.parseAll(body);

    expect(profiles.map((profile) => profile.name), ['A', 'B']);
  });

  test('rejects unsupported schemes', () {
    expect(parser.tryParse('https://example.com'), isNull);
    expect(() => parser.parse('vless://uuid@example.com'), throwsFormatException);
  });
}
