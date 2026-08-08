import 'dart:convert';

/// How traffic reaches Xray.
enum TunnelMode {
  /// Wintun adapter with system routes; captures everything but needs elevation.
  tun,

  /// Local SOCKS/HTTP inbounds, optionally registered as the Windows system proxy.
  systemProxy,
}

class VpnSettings {
  const VpnSettings({
    this.mode = TunnelMode.systemProxy,
    this.setSystemProxy = true,
    this.socksPort = 10808,
    this.httpPort = 10809,
    this.remoteDns = '1.1.1.1',
    this.directDns = '223.5.5.5',
    this.mtu = 1500,
    this.enableIpv6 = false,
    this.bypassLan = true,
    this.bypassMainland = false,
    this.logLevel = 'warning',
  });

  static const logLevels = ['debug', 'info', 'warning', 'error', 'none'];

  final TunnelMode mode;

  /// Only meaningful in [TunnelMode.systemProxy].
  final bool setSystemProxy;
  final int socksPort;
  final int httpPort;
  final String remoteDns;
  final String directDns;
  final int mtu;
  final bool enableIpv6;
  final bool bypassLan;

  /// Route mainland China domains and IPs directly, using the bundled geo files.
  final bool bypassMainland;
  final String logLevel;

  VpnSettings copyWith({
    TunnelMode? mode,
    bool? setSystemProxy,
    int? socksPort,
    int? httpPort,
    String? remoteDns,
    String? directDns,
    int? mtu,
    bool? enableIpv6,
    bool? bypassLan,
    bool? bypassMainland,
    String? logLevel,
  }) {
    return VpnSettings(
      mode: mode ?? this.mode,
      setSystemProxy: setSystemProxy ?? this.setSystemProxy,
      socksPort: socksPort ?? this.socksPort,
      httpPort: httpPort ?? this.httpPort,
      remoteDns: remoteDns ?? this.remoteDns,
      directDns: directDns ?? this.directDns,
      mtu: mtu ?? this.mtu,
      enableIpv6: enableIpv6 ?? this.enableIpv6,
      bypassLan: bypassLan ?? this.bypassLan,
      bypassMainland: bypassMainland ?? this.bypassMainland,
      logLevel: logLevel ?? this.logLevel,
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'setSystemProxy': setSystemProxy,
        'socksPort': socksPort,
        'httpPort': httpPort,
        'remoteDns': remoteDns,
        'directDns': directDns,
        'mtu': mtu,
        'enableIpv6': enableIpv6,
        'bypassLan': bypassLan,
        'bypassMainland': bypassMainland,
        'logLevel': logLevel,
      };

  String encode() => jsonEncode(toMap());

  factory VpnSettings.decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    const fallback = VpnSettings();
    return VpnSettings(
      mode: TunnelMode.values.firstWhere(
        (value) => value.name == map['mode'],
        orElse: () => fallback.mode,
      ),
      setSystemProxy: map['setSystemProxy'] as bool? ?? fallback.setSystemProxy,
      socksPort: (map['socksPort'] as num?)?.toInt() ?? fallback.socksPort,
      httpPort: (map['httpPort'] as num?)?.toInt() ?? fallback.httpPort,
      remoteDns: map['remoteDns'] as String? ?? fallback.remoteDns,
      directDns: map['directDns'] as String? ?? fallback.directDns,
      mtu: (map['mtu'] as num?)?.toInt() ?? fallback.mtu,
      enableIpv6: map['enableIpv6'] as bool? ?? fallback.enableIpv6,
      bypassLan: map['bypassLan'] as bool? ?? fallback.bypassLan,
      bypassMainland: map['bypassMainland'] as bool? ?? fallback.bypassMainland,
      logLevel: map['logLevel'] as String? ?? fallback.logLevel,
    );
  }
}
