enum VpnState { idle, connecting, connected, stopping, error }

class VpnStatus {
  const VpnStatus({
    this.state = VpnState.idle,
    this.message,
    this.profileId,
    this.profileName,
    this.connectedAt,
    this.uplink = 0,
    this.downlink = 0,
  });

  final VpnState state;
  final String? message;
  final String? profileId;
  final String? profileName;
  final DateTime? connectedAt;
  final int uplink;
  final int downlink;

  bool get isActive => state == VpnState.connected || state == VpnState.connecting;

  Duration get uptime =>
      connectedAt == null ? Duration.zero : DateTime.now().difference(connectedAt!);

  VpnStatus copyWith({
    VpnState? state,
    String? message,
    bool clearMessage = false,
    String? profileId,
    String? profileName,
    DateTime? connectedAt,
    bool clearConnectedAt = false,
    int? uplink,
    int? downlink,
  }) {
    return VpnStatus(
      state: state ?? this.state,
      message: clearMessage ? null : (message ?? this.message),
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      connectedAt: clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
      uplink: uplink ?? this.uplink,
      downlink: downlink ?? this.downlink,
    );
  }
}
