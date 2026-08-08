import 'dart:io';

/// TCP handshake latency to the server endpoint, or `null` when unreachable.
///
/// This measures reachability of the endpoint itself, not proxied throughput.
Future<int?> tcpPing(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    stopwatch.stop();
    socket.destroy();
    return stopwatch.elapsedMilliseconds;
  } on SocketException {
    return null;
  } on OSError {
    return null;
  }
}
