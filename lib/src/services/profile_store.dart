import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_profile.dart';
import '../models/vpn_settings.dart';

/// Persists servers, the selected server and the tunnel settings.
class ProfileStore {
  static const _profilesKey = 'profiles';
  static const _selectedKey = 'selectedProfileId';
  static const _settingsKey = 'settings';
  static const _subscriptionKey = 'subscriptionUrl';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<ServerProfile>> loadProfiles() async {
    final raw = (await _prefs).getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    return ServerProfile.decodeList(raw);
  }

  Future<void> saveProfiles(List<ServerProfile> profiles) async {
    await (await _prefs).setString(_profilesKey, ServerProfile.encodeList(profiles));
  }

  Future<String?> loadSelectedId() async => (await _prefs).getString(_selectedKey);

  Future<void> saveSelectedId(String? id) async {
    final prefs = await _prefs;
    if (id == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, id);
    }
  }

  Future<VpnSettings> loadSettings() async {
    final raw = (await _prefs).getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const VpnSettings();
    return VpnSettings.decode(raw);
  }

  Future<void> saveSettings(VpnSettings settings) async {
    await (await _prefs).setString(_settingsKey, settings.encode());
  }

  Future<String?> loadSubscriptionUrl() async =>
      (await _prefs).getString(_subscriptionKey);

  Future<void> saveSubscriptionUrl(String? url) async {
    final prefs = await _prefs;
    if (url == null || url.isEmpty) {
      await prefs.remove(_subscriptionKey);
    } else {
      await prefs.setString(_subscriptionKey, url);
    }
  }
}
