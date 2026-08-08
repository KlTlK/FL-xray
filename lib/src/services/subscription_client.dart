import 'package:http/http.dart' as http;

/// Downloads a subscription body; the payload is parsed by libXray on the native side.
class SubscriptionClient {
  SubscriptionClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> fetch(String url) async {
    final uri = Uri.parse(url.trim());
    if (!uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('Subscription URL must start with http(s)://');
    }
    final response = await _client
        .get(uri, headers: const {'User-Agent': 'FL-xray'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Subscription request failed with HTTP ${response.statusCode}',
        uri,
      );
    }
    return response.body;
  }
}
