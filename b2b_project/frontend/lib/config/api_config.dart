import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL']!;
  static const String apiPath = '/api';
  static String get apiUrl => '$baseUrl$apiPath';
  static String get imageBaseUrl => baseUrl;

  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    // URL'deki encoding sorunlarını düzelt
    // Backend'den gelen \315 gibi escape karakterlerini temizle
    String cleanPath = imagePath.replaceAll(RegExp(r'\\[0-9]{3}'), '');

    final path = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;

    // URL encode et (özel karakterler için)
    final uri = Uri.parse('$imageBaseUrl/$path');
    return uri.toString();
  }

  // Debug amaçlı güvenli log
  static void logApiInfo() {
    if (kDebugMode) {
      print('API Bağlantısı Hazır');
    }
  }
}
