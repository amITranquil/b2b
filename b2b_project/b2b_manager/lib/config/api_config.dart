class ApiConfig {
  // Backend API base URL
  static const String baseUrl = 'https://b2bapi.urlateknik.com:5000';
  static const String apiPath = '/api';

  // Full API URL
  static String get apiUrl => '$baseUrl$apiPath';

  // Image base URL (wwwroot/images)
  static String get imageBaseUrl => baseUrl;

  // Helper method to build image URL
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    // Remove leading slash if exists
    final path = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '$imageBaseUrl/$path';
  }
}
