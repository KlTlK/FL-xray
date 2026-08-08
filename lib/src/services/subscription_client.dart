import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// Downloads a subscription body; the payload is parsed by libXray on the native side.
class SubscriptionClient {
  SubscriptionClient() {
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  final _cookieJar = CookieJar();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    followRedirects: true,
    maxRedirects: 10,
    validateStatus: (status) => status != null && status < 500,
  ));

  Future<String> fetch(String url) async {
    final trimmed = url.trim();
    final uri = Uri.parse(trimmed);
    if (!uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('URL подписки должен начинаться с http(s)://');
    }
    final response = await _dio.get(
      trimmed,
      options: Options(
        headers: {'User-Agent': 'v2rayN/6.23'},
        responseType: ResponseType.plain,
      ),
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Запрос подписки завершился с HTTP ${response.statusCode}',
      );
    }
    return response.data.toString();
  }
}
