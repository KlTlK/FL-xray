import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_xray/src/models/server_profile.dart';
import 'package:fl_xray/src/models/vpn_settings.dart';
import 'package:fl_xray/src/services/profile_store.dart';

ServerProfile _profile(String id) => ServerProfile(
      id: id,
      name: 'Server $id',
      protocol: 'vless',
      address: 'example.com',
      port: 443,
      outbound: '{"protocol":"vless"}',
      network: 'tcp',
      security: 'tls',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profiles survive a serialization round trip', () async {
    final store = ProfileStore();
    await store.saveProfiles([_profile('a'), _profile('b').copyWith(delayMs: 120)]);

    final loaded = await store.loadProfiles();

    expect(loaded, hasLength(2));
    expect(loaded.first.address, 'example.com');
    expect(loaded.last.delayMs, 120);
  });

  test('settings fall back to defaults when unset', () async {
    final store = ProfileStore();

    expect((await store.loadSettings()).remoteDns, const VpnSettings().remoteDns);

    await store.saveSettings(const VpnSettings().copyWith(mtu: 1400, enableIpv6: true));
    final loaded = await store.loadSettings();

    expect(loaded.mtu, 1400);
    expect(loaded.enableIpv6, isTrue);
  });

  test('transport summary skips empty and disabled fields', () {
    expect(_profile('a').transport, 'vless · tcp · tls');
    expect(
      const ServerProfile(
        id: 'x',
        name: 'x',
        protocol: 'shadowsocks',
        address: 'host',
        port: 8388,
        outbound: '{}',
        security: 'none',
      ).transport,
      'shadowsocks',
    );
  });
}
