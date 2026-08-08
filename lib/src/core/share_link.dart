import 'dart:convert';

import '../models/server_profile.dart';

/// Parses `vless://`, `vmess://`, `trojan://` and `ss://` share links into Xray outbounds.
///
/// A whole subscription body (plain lines or base64) can be passed to [parseAll].
class ShareLinkParser {
  const ShareLinkParser();

  static const _supportedSchemes = {'vless', 'vmess', 'trojan', 'ss'};

  List<ServerProfile> parseAll(String text) {
    final body = _maybeDecodeSubscription(text.trim());
    final profiles = <ServerProfile>[];
    for (final line in const LineSplitter().convert(body)) {
      final candidate = line.trim();
      if (candidate.isEmpty || candidate.startsWith('#')) continue;
      final profile = tryParse(candidate);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  ServerProfile? tryParse(String link) {
    try {
      return parse(link);
    } on FormatException {
      return null;
    }
  }

  ServerProfile parse(String link) {
    final scheme = link.split('://').first.toLowerCase();
    if (!_supportedSchemes.contains(scheme) || !link.contains('://')) {
      throw FormatException('Unsupported share link', link);
    }
    switch (scheme) {
      case 'vless':
        return _parseVless(link);
      case 'vmess':
        return _parseVmess(link);
      case 'trojan':
        return _parseTrojan(link);
      default:
        return _parseShadowsocks(link);
    }
  }

  /// A subscription body is usually a base64 blob of newline separated links.
  String _maybeDecodeSubscription(String text) {
    if (text.isEmpty) return text;
    final firstLine = text.split('\n').first.trim().toLowerCase();
    if (_supportedSchemes.any((scheme) => firstLine.startsWith('$scheme://'))) {
      return text;
    }
    final decoded = _tryDecodeBase64(text.replaceAll(RegExp(r'\s'), ''));
    return decoded ?? text;
  }

  static String? _tryDecodeBase64(String value) {
    try {
      final normalized = base64.normalize(
        value.replaceAll('-', '+').replaceAll('_', '/'),
      );
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return null;
    }
  }

  ServerProfile _parseVless(String link) {
    final uri = Uri.parse(link);
    final id = Uri.decodeComponent(uri.userInfo);
    final query = uri.queryParameters;
    final host = _requireHost(uri, link);
    final port = _requirePort(uri, link);

    final user = <String, dynamic>{
      'id': id,
      'encryption': query['encryption'] ?? 'none',
    };
    final flow = query['flow'];
    if (flow != null && flow.isNotEmpty) user['flow'] = flow;

    return _profile(
      name: _remark(uri, '$host:$port'),
      protocol: 'vless',
      address: host,
      port: port,
      outbound: {
        'protocol': 'vless',
        'settings': {
          'vnext': [
            {'address': host, 'port': port, 'users': [user]},
          ],
        },
        'streamSettings': _streamSettings(query, host),
      },
      query: query,
    );
  }

  ServerProfile _parseVmess(String link) {
    final payload = _tryDecodeBase64(link.substring('vmess://'.length).trim());
    if (payload == null) {
      throw FormatException('vmess link is not valid base64', link);
    }
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final host = (json['add'] as String?)?.trim() ?? '';
    final port = int.tryParse('${json['port']}') ?? 0;
    if (host.isEmpty || port == 0) {
      throw FormatException('vmess link has no address', link);
    }

    // VMessAEAD share links reuse a flat set of keys for every transport.
    final query = <String, String>{
      'type': (json['net'] as String?) ?? 'tcp',
      'security': (json['tls'] as String?)?.isNotEmpty == true
          ? json['tls'] as String
          : 'none',
      if (json['host'] != null) 'host': '${json['host']}',
      if (json['path'] != null) 'path': '${json['path']}',
      if (json['sni'] != null) 'sni': '${json['sni']}',
      if (json['alpn'] != null) 'alpn': '${json['alpn']}',
      if (json['fp'] != null) 'fp': '${json['fp']}',
      if (json['scy'] != null) 'scy': '${json['scy']}',
    };

    return _profile(
      name: (json['ps'] as String?)?.trim().isNotEmpty == true
          ? (json['ps'] as String).trim()
          : '$host:$port',
      protocol: 'vmess',
      address: host,
      port: port,
      outbound: {
        'protocol': 'vmess',
        'settings': {
          'vnext': [
            {
              'address': host,
              'port': port,
              'users': [
                {
                  'id': '${json['id']}',
                  'alterId': int.tryParse('${json['aid'] ?? 0}') ?? 0,
                  'security': query['scy'] ?? 'auto',
                },
              ],
            },
          ],
        },
        'streamSettings': _streamSettings(query, host),
      },
      query: query,
    );
  }

  ServerProfile _parseTrojan(String link) {
    final uri = Uri.parse(link);
    final query = uri.queryParameters;
    final host = _requireHost(uri, link);
    final port = _requirePort(uri, link);
    return _profile(
      name: _remark(uri, '$host:$port'),
      protocol: 'trojan',
      address: host,
      port: port,
      outbound: {
        'protocol': 'trojan',
        'settings': {
          'servers': [
            {
              'address': host,
              'port': port,
              'password': Uri.decodeComponent(uri.userInfo),
            },
          ],
        },
        'streamSettings': _streamSettings(
          {'security': query['security'] ?? 'tls', ...query},
          host,
        ),
      },
      query: query,
    );
  }

  ServerProfile _parseShadowsocks(String link) {
    // ss://base64(method:password)@host:port#remark or ss://base64(everything)#remark
    final hashIndex = link.indexOf('#');
    final remark = hashIndex == -1
        ? null
        : Uri.decodeComponent(link.substring(hashIndex + 1));
    var body = hashIndex == -1 ? link : link.substring(0, hashIndex);
    body = body.substring('ss://'.length);

    final queryIndex = body.indexOf('?');
    final query = queryIndex == -1
        ? const <String, String>{}
        : Uri.splitQueryString(body.substring(queryIndex + 1));
    if (queryIndex != -1) body = body.substring(0, queryIndex);

    if (!body.contains('@')) {
      final decoded = _tryDecodeBase64(body);
      if (decoded == null) throw FormatException('Malformed ss link', link);
      body = decoded;
    }

    final at = body.lastIndexOf('@');
    if (at == -1) throw FormatException('Malformed ss link', link);
    var credentials = body.substring(0, at);
    final endpoint = body.substring(at + 1);
    if (!credentials.contains(':')) {
      credentials = _tryDecodeBase64(credentials) ?? credentials;
    }
    final separator = credentials.indexOf(':');
    if (separator == -1) throw FormatException('Malformed ss credentials', link);

    final colon = endpoint.lastIndexOf(':');
    if (colon == -1) throw FormatException('Malformed ss endpoint', link);
    final host = endpoint.substring(0, colon);
    final port = int.tryParse(endpoint.substring(colon + 1)) ?? 0;
    if (host.isEmpty || port == 0) throw FormatException('Malformed ss endpoint', link);

    return _profile(
      name: remark?.trim().isNotEmpty == true ? remark!.trim() : '$host:$port',
      protocol: 'shadowsocks',
      address: host,
      port: port,
      outbound: {
        'protocol': 'shadowsocks',
        'settings': {
          'servers': [
            {
              'address': host,
              'port': port,
              'method': credentials.substring(0, separator),
              'password': credentials.substring(separator + 1),
            },
          ],
        },
        'streamSettings': _streamSettings(query, host),
      },
      query: query,
    );
  }

  Map<String, dynamic> _streamSettings(Map<String, String> query, String host) {
    final network = query['type'] ?? 'tcp';
    final security = query['security'] ?? 'none';
    final settings = <String, dynamic>{
      'network': network,
      'security': security,
    };

    switch (network) {
      case 'ws':
        settings['wsSettings'] = {
          'path': query['path'] ?? '/',
          if ((query['host'] ?? '').isNotEmpty)
            'headers': {'Host': query['host']},
        };
      case 'grpc':
        settings['grpcSettings'] = {
          'serviceName': query['serviceName'] ?? '',
          'multiMode': query['mode'] == 'multi',
        };
      case 'httpupgrade':
        settings['httpupgradeSettings'] = {
          'path': query['path'] ?? '/',
          'host': query['host'] ?? '',
        };
      case 'xhttp':
      case 'splithttp':
        settings['xhttpSettings'] = {
          'path': query['path'] ?? '/',
          'host': query['host'] ?? '',
          if ((query['mode'] ?? '').isNotEmpty) 'mode': query['mode'],
        };
      case 'tcp':
        if (query['headerType'] == 'http') {
          settings['tcpSettings'] = {
            'header': {
              'type': 'http',
              'request': {
                'path': [query['path'] ?? '/'],
                'headers': {
                  'Host': [query['host'] ?? host],
                },
              },
            },
          };
        }
    }

    if (security == 'tls') {
      settings['tlsSettings'] = {
        'serverName': query['sni'] ?? query['host'] ?? host,
        'allowInsecure': query['allowInsecure'] == '1',
        if ((query['alpn'] ?? '').isNotEmpty) 'alpn': query['alpn']!.split(','),
        if ((query['fp'] ?? '').isNotEmpty) 'fingerprint': query['fp'],
      };
    } else if (security == 'reality') {
      settings['realitySettings'] = {
        'serverName': query['sni'] ?? host,
        'publicKey': query['pbk'] ?? '',
        'shortId': query['sid'] ?? '',
        'spiderX': query['spx'] ?? '',
        if ((query['fp'] ?? '').isNotEmpty) 'fingerprint': query['fp'],
      };
    }
    return settings;
  }

  ServerProfile _profile({
    required String name,
    required String protocol,
    required String address,
    required int port,
    required Map<String, dynamic> outbound,
    required Map<String, String> query,
  }) {
    return ServerProfile(
      id: '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(outbound)}',
      name: name,
      protocol: protocol,
      address: address,
      port: port,
      outbound: jsonEncode(outbound),
      network: query['type'] ?? 'tcp',
      security: query['security'] ?? 'none',
    );
  }

  String _remark(Uri uri, String fallback) {
    final fragment = uri.fragment.trim();
    return fragment.isEmpty ? fallback : Uri.decodeComponent(fragment);
  }

  String _requireHost(Uri uri, String link) {
    if (uri.host.isEmpty) throw FormatException('Link has no host', link);
    return uri.host;
  }

  int _requirePort(Uri uri, String link) {
    if (!uri.hasPort || uri.port == 0) {
      throw FormatException('Link has no port', link);
    }
    return uri.port;
  }
}
