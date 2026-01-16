// lib/config/api_config.dart
class ApiConfig {
  // Backend API base URL
  static const String baseUrl = 'https://b2bapi.urlateknik.com:5000';
  static const String apiPath = '/api';

  // Full API URL
  static String get apiUrl => '$baseUrl$apiPath';

  // Endpoints
  static String quotesEndpoint(String? id) =>
      id != null ? '$apiUrl/quotes/$id' : '$apiUrl/quotes';
}
