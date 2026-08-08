import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/elevation.dart';
import '../core/share_link.dart';
import '../core/system_proxy.dart';
import '../core/tcp_ping.dart';
import '../core/xray_process.dart';
import '../models/server_profile.dart';
import '../models/vpn_settings.dart';
import '../models/vpn_status.dart';
import '../services/profile_store.dart';
import '../services/subscription_client.dart';

/// Raised when TUN mode is requested without administrator rights.
class ElevationRequired implements Exception {}

/// Owns the server list, the tunnel settings and the Xray-core child process.
class VpnController extends ChangeNotifier {
  VpnController({
    XrayProcess? process,
    ProfileStore? store,
    SubscriptionClient? subscriptions,
    SystemProxy? systemProxy,
    Elevation? elevation,
    ShareLinkParser parser = const ShareLinkParser(),
  })  : _process = process ?? XrayProcess(),
        _store = store ?? ProfileStore(),
        _subscriptions = subscriptions ?? SubscriptionClient(),
        _systemProxy = systemProxy ?? const SystemProxy(),
        _elevation = elevation ?? const Elevation(),
        _parser = parser;

  static const _maxLogLines = 500;

  final XrayProcess _process;
  final ProfileStore _store;
  final SubscriptionClient _subscriptions;
  final SystemProxy _systemProxy;
  final Elevation _elevation;
  final ShareLinkParser _parser;

  final List<String> _logs = [];
  final List<StreamSubscription<Object?>> _subscriptionsToCancel = [];

  List<ServerProfile> _profiles = [];
  String? _selectedId;
  VpnSettings _settings = const VpnSettings();
  VpnStatus _status = const VpnStatus();
  String? _subscriptionUrl;
  bool _busy = false;
  bool _ready = false;
  bool _systemProxyApplied = false;

  List<ServerProfile> get profiles => List.unmodifiable(_profiles);
  VpnSettings get settings => _settings;
  VpnStatus get status => _status;
  String? get subscriptionUrl => _subscriptionUrl;
  List<String> get logs => List.unmodifiable(_logs);
  bool get busy => _busy;
  bool get ready => _ready;
  bool get isElevated => _elevation.isElevated;
  bool get coreInstalled => _process.paths.isBundled;

  ServerProfile? get selected {
    for (final profile in _profiles) {
      if (profile.id == _selectedId) return profile;
    }
    return null;
  }

  Future<void> initialize() async {
    _profiles = await _store.loadProfiles();
    _selectedId = await _store.loadSelectedId();
    _settings = await _store.loadSettings();
    _subscriptionUrl = await _store.loadSubscriptionUrl();

    _subscriptionsToCancel.addAll([
      _process.logs.listen(_appendLog),
      _process.traffic.listen((traffic) {
        _status = _status.copyWith(
          uplink: traffic.uplink,
          downlink: traffic.downlink,
        );
        notifyListeners();
      }),
      _process.exits.listen(_onCoreExit),
    ]);

    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptionsToCancel) {
      subscription.cancel();
    }
    unawaited(_process.dispose());
    super.dispose();
  }

  Future<void> select(String id) async {
    _selectedId = id;
    await _store.saveSelectedId(id);
    notifyListeners();
  }

  /// Imports share links or a subscription body. Returns the number of servers added.
  Future<int> importText(String text) async {
    final imported = _parser.parseAll(text);
    if (imported.isEmpty) return 0;
    _profiles = [..._profiles, ...imported];
    _selectedId ??= _profiles.first.id;
    await _persistProfiles();
    return imported.length;
  }

  Future<int> importSubscription(String url) async {
    final body = await _subscriptions.fetch(url);
    _subscriptionUrl = url.trim();
    await _store.saveSubscriptionUrl(_subscriptionUrl);
    return importText(body);
  }

  Future<void> rename(ServerProfile profile, String name) async {
    _profiles = _profiles
        .map((item) => item.id == profile.id ? item.copyWith(name: name) : item)
        .toList();
    await _persistProfiles();
  }

  Future<void> remove(ServerProfile profile) async {
    _profiles = _profiles.where((item) => item.id != profile.id).toList();
    if (_selectedId == profile.id) {
      _selectedId = _profiles.isEmpty ? null : _profiles.first.id;
      await _store.saveSelectedId(_selectedId);
    }
    await _persistProfiles();
  }

  Future<void> clearProfiles() async {
    _profiles = [];
    _selectedId = null;
    await _store.saveSelectedId(null);
    await _persistProfiles();
  }

  Future<void> updateSettings(VpnSettings settings) async {
    _settings = settings;
    await _store.saveSettings(settings);
    notifyListeners();
  }

  Future<void> measureLatency() async {
    if (_profiles.isEmpty || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      final delays = await Future.wait(
        _profiles.map((profile) => tcpPing(profile.address, profile.port)),
      );
      _profiles = [
        for (var index = 0; index < _profiles.length; index++)
          delays[index] == null
              ? _profiles[index].copyWith(clearDelay: true)
              : _profiles[index].copyWith(delayMs: delays[index]),
      ];
      await _persistProfiles();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Starts the tunnel. Returns an error message, or `null` on success.
  /// Throws [ElevationRequired] when TUN mode needs a UAC restart.
  Future<String?> connect() async {
    final profile = selected;
    if (profile == null) return 'Select a server first';
    if (_status.isActive) return null;
    if (_settings.mode == TunnelMode.tun && !_elevation.isElevated) {
      throw ElevationRequired();
    }

    _status = VpnStatus(
      state: VpnState.connecting,
      profileId: profile.id,
      profileName: profile.name,
    );
    notifyListeners();

    try {
      await _process.start(profile, _settings);
      if (_settings.mode == TunnelMode.systemProxy && _settings.setSystemProxy) {
        _systemProxy.enable(_settings.httpPort);
        _systemProxyApplied = true;
      }
      _status = _status.copyWith(
        state: VpnState.connected,
        connectedAt: DateTime.now(),
        clearMessage: true,
      );
      notifyListeners();
      return null;
    } catch (error) {
      await _teardown();
      _status = _status.copyWith(
        state: VpnState.error,
        message: '$error',
        clearConnectedAt: true,
      );
      notifyListeners();
      return '$error';
    }
  }

  Future<void> disconnect() async {
    if (_status.state == VpnState.idle) return;
    _status = _status.copyWith(state: VpnState.stopping);
    notifyListeners();
    await _teardown();
    _status = const VpnStatus();
    notifyListeners();
  }

  /// Restarts the app through UAC so that TUN mode can create the adapter.
  bool relaunchElevated() => _elevation.relaunchElevated();

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> _teardown() async {
    await _process.stop();
    if (_systemProxyApplied) {
      _systemProxy.disable();
      _systemProxyApplied = false;
    }
  }

  void _onCoreExit(int code) {
    if (_status.state == VpnState.idle || _status.state == VpnState.stopping) {
      return;
    }
    if (_systemProxyApplied) {
      _systemProxy.disable();
      _systemProxyApplied = false;
    }
    _status = _status.copyWith(
      state: VpnState.error,
      message: 'Xray exited with code $code',
      clearConnectedAt: true,
    );
    notifyListeners();
  }

  void _appendLog(String line) {
    _logs.add(line);
    if (_logs.length > _maxLogLines) _logs.removeAt(0);
    notifyListeners();
  }

  Future<void> _persistProfiles() async {
    await _store.saveProfiles(_profiles);
    notifyListeners();
  }
}
