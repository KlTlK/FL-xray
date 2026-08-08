import 'dart:io';

/// Downloads a subscription body using system curl (proper TLS fingerprint + cookies).
class SubscriptionClient {
  Future<String> fetch(String url) async {
    final trimmed = url.trim();
    final uri = Uri.parse(trimmed);
    if (!uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('URL подписки должен начинаться с http(s)://');
    }

    final tmpOut = '${Directory.systemTemp.path}${Platform.pathSeparator}fl_xray_sub.txt';
    final tmpCookie = '${Directory.systemTemp.path}${Platform.pathSeparator}fl_xray_cookies.txt';

    try { File(tmpOut).deleteSync(); } catch (_) {}
    try { File(tmpCookie).deleteSync(); } catch (_) {}

    final result = await Process.run('curl', [
      '-L',
      '-s', '-S',
      '--max-redirs', '10',
      '-c', tmpCookie,
      '-b', tmpCookie,
      '-A', 'v2rayN/6.23',
      '-o', tmpOut,
      '--connect-timeout', '15',
      '--max-time', '30',
      trimmed,
    ]);

    if (result.exitCode != 0) {
      throw StateError('curl error ${result.exitCode}: ${result.stderr.toString().trim()}');
    }

    final file = File(tmpOut);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('Пустой ответ от сервера');
    }

    final body = file.readAsStringSync();

    try { File(tmpOut).deleteSync(); } catch (_) {}
    try { File(tmpCookie).deleteSync(); } catch (_) {}

    return body;
  }
}
