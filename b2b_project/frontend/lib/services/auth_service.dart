import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _tokenExpiryKey = 'token_expiry';
  final String baseUrl = ApiConfig.apiUrl;
  final http.Client _client = http.Client();

  /// JWT ile login - PIN doğrulama yapıp JWT token alır
  Future<Map<String, dynamic>?> login(String pin) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'pin': pin}),
      );

      log("Login response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['token'] != null) {
          // JWT token'ı kaydet
          await saveToken(data['token'], data['expiresIn'] ?? 3600);
          return data;
        }
      } else {
        log("Error response body: ${response.body}");
      }
      return null;
    } catch (e) {
      log("Exception in login: $e");
      return null;
    }
  }

  /// Geriye uyumluluk için eski verify-pin endpoint'i (artık login kullanılmalı)
  @Deprecated('Use login() instead')
  Future<bool> verifyPin(String pin) async {
    final result = await login(pin);
    return result != null && result['success'] == true;
  }

  /// JWT token'ı kaydet
  Future<void> saveToken(String token, int expiresInSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtTokenKey, token);

    // Token'ın sona erme zamanını hesapla ve kaydet
    final expiryTime = DateTime.now().add(Duration(seconds: expiresInSeconds));
    await prefs.setInt(_tokenExpiryKey, expiryTime.millisecondsSinceEpoch);

    log("JWT token saved, expires at: $expiryTime");
  }

  /// Geriye uyumluluk için
  @Deprecated('Use saveToken() instead')
  Future<void> saveSession(String pin) async {
    // Bu metod artık kullanılmıyor, login() kullanılmalı
    log("Warning: saveSession is deprecated, use login() instead");
  }

  /// JWT token'ı al
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_jwtTokenKey);
  }

  /// Oturum geçerliliğini kontrol et (token süresine göre)
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_jwtTokenKey);
    final expiryTime = prefs.getInt(_tokenExpiryKey);

    if (token == null || expiryTime == null) {
      return false;
    }

    final expiryDateTime = DateTime.fromMillisecondsSinceEpoch(expiryTime);
    final now = DateTime.now();

    // Token süresi dolmuşsa oturumu sonlandır
    if (now.isAfter(expiryDateTime)) {
      await logout();
      log("Token expired, logged out");
      return false;
    }

    return true;
  }

  /// Oturumu sonlandır
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtTokenKey);
    await prefs.remove(_tokenExpiryKey);
    log("Logged out, token removed");
  }

  /// Authorization header oluştur
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token != null) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  /// Oturum süresini yenile - JWT'de gerek yok, token zaten expiry içeriyor
  @Deprecated('Not needed with JWT authentication')
  Future<void> refreshSession() async {
    // JWT authentication ile bu metod gerekli değil
    log("Warning: refreshSession is deprecated with JWT authentication");
  }

  /// PIN değiştirme
  Future<Map<String, dynamic>?> changePin(
      String currentPin, String newPin) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/update-pin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'currentPin': currentPin,
          'newPin': newPin,
          'updatedBy': 'Web Kullanıcısı'
        }),
      );

      log("Change PIN response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Mevcut PIN hatalı'};
      } else {
        log("Error response body: ${response.body}");
        return {'success': false, 'message': 'PIN güncellenemedi'};
      }
    } catch (e) {
      log("Exception in changePin: $e");
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  void dispose() {
    _client.close();
  }
}
