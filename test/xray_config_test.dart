import 'package:flutter_test/flutter_test.dart';

import 'package:fl_xray/src/core/xray_config.dart';
import 'package:fl_xray/src/models/server_profile.dart';
import 'package:fl_xray/src/models/vpn_settings.dart';

const _profile = ServerProfile(
  id: 'a',
  name: 'Server',
  protocol: 'vless',
  address: 'example.com',
  port: 443,
  outbound: '{"protocol":"vless","settings":{}}',
);

List<Map<String, dynamic>> _inbounds(Map<String, dynamic> config) =>
    (config['inbounds'] as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _rules(Map<String, dynamic> config) =>
    ((config['routing'] as Map)['rules'] as List).cast<Map<String, dynamic>>();

void main() {
  const builder = XrayConfigBuilder();

  test('system proxy mode exposes socks and http only', () {
    final config = builder.buildMap(_profile, const VpnSettings());

    expect(
      _inbounds(config).map((inbound) => inbound['tag']),
      [XrayConfigBuilder.socksTag, XrayConfigBuilder.httpTag],
    );
    expect(_inbounds(config).first['port'], 10808);
  });

  test('tun mode adds a wintun inbound with split default routes', () {
    final config = builder.buildMap(
      _profile,
      const VpnSettings(mode: TunnelMode.tun, mtu: 1400),
    );

    final tun = _inbounds(config).first;
    expect(tun['tag'], XrayConfigBuilder.tunTag);
    final settings = tun['settings'] as Map<String, dynamic>;
    expect(settings['mtu'], 1400);
    expect(settings['autoSystemRoutingTable'], ['0.0.0.0/1', '128.0.0.0/1']);
    expect(settings['autoOutboundsInterface'], 'auto');
  });

  test('ipv6 is blocked unless enabled, and routed when enabled', () {
    final blocked = _rules(builder.buildMap(_profile, const VpnSettings()));
    expect(
      blocked.any((rule) =>
          rule['outboundTag'] == XrayConfigBuilder.blockTag &&
          (rule['ip'] as List).contains('::/0')),
      isTrue,
    );

    final config = builder.buildMap(
      _profile,
      const VpnSettings(mode: TunnelMode.tun, enableIpv6: true),
    );
    expect(
      _rules(config).any((rule) => rule['outboundTag'] == XrayConfigBuilder.blockTag),
      isFalse,
    );
    expect(
      (_inbounds(config).first['settings'] as Map)['autoSystemRoutingTable'],
      ['0.0.0.0/1', '128.0.0.0/1', '::/1', '8000::/1'],
    );
  });

  test('the selected outbound is tagged as the proxy and kept first', () {
    final outbounds = (builder.buildMap(_profile, const VpnSettings())['outbounds']
            as List)
        .cast<Map<String, dynamic>>();

    expect(outbounds.first['tag'], XrayConfigBuilder.proxyTag);
    expect(outbounds.first['protocol'], 'vless');
    expect(
      outbounds.map((outbound) => outbound['tag']),
      containsAll([
        XrayConfigBuilder.directTag,
        XrayConfigBuilder.blockTag,
        XrayConfigBuilder.dnsTag,
      ]),
    );
  });

  test('mainland bypass adds direct geo rules and a direct dns server', () {
    final config = builder.buildMap(
      _profile,
      const VpnSettings(bypassMainland: true, directDns: '223.5.5.5'),
    );

    expect(
      _rules(config).where((rule) => rule['outboundTag'] == XrayConfigBuilder.directTag),
      hasLength(4),
    );
    expect(((config['dns'] as Map)['servers'] as List).last, isA<Map>());
  });
}
