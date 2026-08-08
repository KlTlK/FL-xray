import 'dart:convert';

/// A single proxy server, stored as the Xray outbound it maps to.
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    required this.outbound,
    this.network = '',
    this.security = '',
    this.delayMs,
  });

  final String id;
  final String name;
  final String protocol;
  final String address;
  final int port;

  /// The Xray outbound object, serialized as JSON.
  final String outbound;
  final String network;
  final String security;

  /// Latency of the last measurement, `null` when never measured or unreachable.
  final int? delayMs;

  String get endpoint => port == 0 ? address : '$address:$port';

  String get transport {
    final parts = <String>[
      if (protocol.isNotEmpty) protocol,
      if (network.isNotEmpty) network,
      if (security.isNotEmpty && security != 'none') security,
    ];
    return parts.join(' · ');
  }

  ServerProfile copyWith({String? name, int? delayMs, bool clearDelay = false}) {
    return ServerProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol,
      address: address,
      port: port,
      outbound: outbound,
      network: network,
      security: security,
      delayMs: clearDelay ? null : (delayMs ?? this.delayMs),
    );
  }

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: json['protocol'] as String? ?? '',
      address: json['address'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      outbound: json['outbound'] as String? ?? '{}',
      network: json['network'] as String? ?? '',
      security: json['security'] as String? ?? '',
      delayMs: (json['delayMs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol,
        'address': address,
        'port': port,
        'outbound': outbound,
        'network': network,
        'security': security,
        'delayMs': delayMs,
      };

  static String encodeList(List<ServerProfile> profiles) =>
      jsonEncode(profiles.map((profile) => profile.toJson()).toList());

  static List<ServerProfile> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => ServerProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
