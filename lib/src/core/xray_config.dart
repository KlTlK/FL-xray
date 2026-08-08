import 'dart:convert';

import '../models/server_profile.dart';
import '../models/vpn_settings.dart';

/// Generates the Xray-core configuration for both tunnelling modes.
class XrayConfigBuilder {
  const XrayConfigBuilder();

  static const proxyTag = 'proxy';
  static const directTag = 'direct';
  static const blockTag = 'block';
  static const dnsTag = 'dns-out';
  static const tunTag = 'tun-in';
  static const socksTag = 'socks-in';
  static const httpTag = 'http-in';

  static const tunAdapterName = 'xray0';
  static const tunGateway = '10.10.10.1/30';
  static const metricsHost = '127.0.0.1';
  static const metricsPort = 49227;

  String build(ServerProfile profile, VpnSettings settings) =>
      const JsonEncoder.withIndent('  ').convert(buildMap(profile, settings));

  Map<String, dynamic> buildMap(ServerProfile profile, VpnSettings settings) {
    final proxy = Map<String, dynamic>.from(
      jsonDecode(profile.outbound) as Map<String, dynamic>,
    )..['tag'] = proxyTag;

    return {
      'log': {'loglevel': settings.logLevel},
      'dns': _dns(settings),
      'inbounds': _inbounds(settings),
      'outbounds': [
        proxy,
        {'tag': directTag, 'protocol': 'freedom'},
        {'tag': blockTag, 'protocol': 'blackhole'},
        {
          'tag': dnsTag,
          'protocol': 'dns',
          'settings': {'nonIPQuery': 'skip'},
        },
      ],
      'routing': _routing(settings),
      'metrics': {'listen': '$metricsHost:$metricsPort'},
      'policy': {
        'system': {'statsOutboundUplink': true, 'statsOutboundDownlink': true},
      },
      'stats': <String, dynamic>{},
    };
  }

  Map<String, dynamic> _dns(VpnSettings settings) {
    final servers = <dynamic>[settings.remoteDns];
    if (settings.bypassMainland) {
      servers.add({
        'address': settings.directDns,
        'domains': ['geosite:cn'],
        'expectIPs': ['geoip:cn'],
        'skipFallback': true,
      });
    }
    return {
      'servers': servers,
      'queryStrategy': settings.enableIpv6 ? 'UseIP' : 'UseIPv4',
    };
  }

  List<Map<String, dynamic>> _inbounds(VpnSettings settings) {
    final inbounds = <Map<String, dynamic>>[
      {
        'tag': socksTag,
        'listen': '127.0.0.1',
        'port': settings.socksPort,
        'protocol': 'socks',
        'settings': {'udp': true, 'auth': 'noauth'},
        'sniffing': _sniffing(),
      },
      {
        'tag': httpTag,
        'listen': '127.0.0.1',
        'port': settings.httpPort,
        'protocol': 'http',
        'settings': <String, dynamic>{},
        'sniffing': _sniffing(),
      },
    ];

    if (settings.mode == TunnelMode.tun) {
      // Two /1 routes outrank the physical default route without replacing it,
      // and `autoOutboundsInterface` keeps Xray's own uplink off the adapter.
      final routes = <String>['0.0.0.0/1', '128.0.0.0/1'];
      if (settings.enableIpv6) {
        routes.addAll(['::/1', '8000::/1']);
      }
      inbounds.insert(0, {
        'tag': tunTag,
        'port': 0,
        'protocol': 'tun',
        'settings': {
          'name': tunAdapterName,
          'desc': 'FL-xray Tunnel',
          'mtu': settings.mtu,
          'gateway': [tunGateway],
          'dns': [settings.remoteDns],
          'autoSystemRoutingTable': routes,
          'autoOutboundsInterface': 'auto',
        },
        'sniffing': _sniffing(),
      });
    }
    return inbounds;
  }

  Map<String, dynamic> _sniffing() => {
        'enabled': true,
        'destOverride': ['http', 'tls', 'quic'],
        'routeOnly': false,
      };

  Map<String, dynamic> _routing(VpnSettings settings) {
    final rules = <Map<String, dynamic>>[
      {'type': 'field', 'port': 53, 'outboundTag': dnsTag},
    ];
    if (settings.bypassLan) {
      rules.add({
        'type': 'field',
        'ip': ['geoip:private'],
        'outboundTag': directTag,
      });
      rules.add({
        'type': 'field',
        'domain': ['geosite:private'],
        'outboundTag': directTag,
      });
    }
    if (settings.bypassMainland) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:cn'],
        'outboundTag': directTag,
      });
      rules.add({
        'type': 'field',
        'ip': ['geoip:cn'],
        'outboundTag': directTag,
      });
    }
    if (!settings.enableIpv6) {
      rules.add({
        'type': 'field',
        'ip': ['::/0'],
        'outboundTag': blockTag,
      });
    }
    return {'domainStrategy': 'IPIfNonMatch', 'rules': rules};
  }
}
