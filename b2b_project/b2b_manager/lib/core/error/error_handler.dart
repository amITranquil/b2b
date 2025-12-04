// lib/core/error/error_handler.dart
import 'dart:developer';
import 'exceptions.dart';

/// Single Responsibility: Error handling logic
class ErrorHandler {
  static String getUserMessage(dynamic error) {
    if (error is NetworkException) {
      return 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.';
    } else if (error is UnauthorizedException) {
      return 'Oturum süresi dolmuş olabilir. Lütfen yeniden giriş yapın.';
    } else if (error is NotFoundException) {
      return 'Kayıt bulunamadı.';
    } else if (error is ApiException) {
      if (error.statusCode == 403) {
        return 'Bu işlem için yetkiniz bulunmuyor.';
      }
      return 'Sunucu hatası: ${error.message}';
    } else if (error is ValidationException) {
      return error.message;
    } else if (error is AppException) {
      return error.message;
    }

    return 'Beklenmeyen bir hata oluştu: $error';
  }

  static void logError(dynamic error, {StackTrace? stackTrace, String? context}) {
    log(
      'Error${context != null ? ' in $context' : ''}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
