import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configurações centrais da aplicação e endpoints de backend
class AppConfig {
  AppConfig._();

  static String get backendBaseUrl {
    final url = dotenv.env['API_URL']?.trim();
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return 'http://127.0.0.1:8000';
  }
}
