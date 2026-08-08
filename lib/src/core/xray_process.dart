import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/server_profile.dart';
import '../models/vpn_settings.dart';
import 'xray_config.dart';
import 'xray_paths.dart';

class XrayTraffic {
  const XrayTraffic({this.uplink = 0, this.downlink = 0});

  final int uplink;
  final int downlink;
}

/// Supervises the bundled `xray.exe` child process.
class XrayProcess {
  XrayProcess({XrayPaths? paths, http.Client? client})
      : _paths = paths ?? XrayPaths(),
        _client = client ?? http.Client();

  static const _statsInterval = Duration(seconds: 1);
  static const _startupGrace = Duration(milliseconds: 800);

  final XrayPaths _paths;
  final http.Client _client;
  final _logs = StreamController<String>.broadcast();
  final _traffic = StreamController<XrayTraffic>.broadcast();
  final _exits = StreamController<int>.broadcast();

  Process? _process;
  Timer? _statsTimer;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;

  Stream<String> get logs => _logs.stream;
  Stream<XrayTraffic> get traffic => _traffic.stream;

  /// Emits the exit code whenever the core stops on its own.
  Stream<int> get exits => _exits.stream;

  bool get isRunning => _process != null;

  XrayPaths get paths => _paths;

  Future<void> start(ServerProfile profile, VpnSettings settings) async {
    if (_process != null) {
      throw StateError('Xray is already running');
    }
    if (!_paths.isBundled) {
      throw XrayLaunchException(
        'xray.exe was not found at ${_paths.executable.path}. '
        'Rebuild the app so the core is installed next to it.',
      );
    }

    await _paths.dataDir.create(recursive: true);
    final config = const XrayConfigBuilder().build(profile, settings);
    await _paths.configFile.writeAsString(config);

    final process = await Process.start(
      _paths.executable.path,
      ['run', '-c', _paths.configFile.path],
      workingDirectory: _paths.bundleDir.path,
      environment: {'XRAY_LOCATION_ASSET': _paths.bundleDir.path},
    );
    _process = process;

    _stdout = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_logs.add);
    _stderr = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_logs.add);

    unawaited(
      process.exitCode.then((code) {
        if (_process?.pid == process.pid) {
          _cleanup();
          _exits.add(code);
        }
      }),
    );

    // A config error makes the core exit almost immediately; surface it as a failure.
    await Future<void>.delayed(_startupGrace);
    if (_process == null) {
      throw XrayLaunchException(
        'Xray exited during start-up. Check the log tab for the reason.',
      );
    }

    _statsTimer = Timer.periodic(_statsInterval, (_) => _pollStats(settings));
  }

  Future<void> stop() async {
    final process = _process;
    _cleanup();
    if (process == null) return;
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }

  Future<void> _pollStats(VpnSettings settings) async {
    final uri = Uri.parse(
      'http://${XrayConfigBuilder.metricsHost}:${XrayConfigBuilder.metricsPort}/debug/vars',
    );
    try {
      final response = await _client.get(uri).timeout(_statsInterval);
      if (response.statusCode != 200) return;
      final stats = (jsonDecode(response.body) as Map<String, dynamic>)['stats'];
      final outbound = (stats as Map<String, dynamic>?)?['outbound'];
      final proxy = (outbound as Map<String, dynamic>?)?[XrayConfigBuilder.proxyTag];
      if (proxy is! Map<String, dynamic>) return;
      _traffic.add(
        XrayTraffic(
          uplink: (proxy['uplink'] as num?)?.toInt() ?? 0,
          downlink: (proxy['downlink'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {
      // The metrics endpoint is only available while the core is up; ignore blips.
    }
  }

  void _cleanup() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _stdout?.cancel();
    _stdout = null;
    _stderr?.cancel();
    _stderr = null;
    _process = null;
  }

  Future<void> dispose() async {
    await stop();
    await _logs.close();
    await _traffic.close();
    await _exits.close();
    _client.close();
  }
}

class XrayLaunchException implements Exception {
  const XrayLaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}
