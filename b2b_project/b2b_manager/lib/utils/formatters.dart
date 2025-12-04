import 'package:intl/intl.dart';

/// Fiyat formatlama yardımcı sınıfı
class CurrencyFormatter {
  /// Para birimi formatla (TL)
  /// Tam sayı ise ondalık kısmı göstermez: 100 ₺
  /// Ondalık varsa 2 basamak gösterir: 100,50 ₺
  static String format(double amount) {
    // Tam sayı ise ondalık kısmı gösterme
    if (amount == amount.truncate()) {
      return NumberFormat.currency(
        locale: 'tr_TR',
        symbol: '₺',
        decimalDigits: 0,
      ).format(amount);
    }
    // Ondalık varsa 2 basamak göster
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    ).format(amount);
  }
}

/// Yüzde formatlama yardımcı sınıfı
class PercentageFormatter {
  /// Yüzde formatla
  /// Tam sayı ise ondalık göstermez: 40%
  /// Ondalık varsa 1 basamak gösterir: 40,5%
  static String format(double value) {
    // Tam sayı ise ondalık gösterme
    if (value == value.truncate()) {
      return value.toStringAsFixed(0);
    }
    // Ondalık varsa 1 basamak göster
    return value.toStringAsFixed(1);
  }

  /// Yüzde işareti ile birlikte formatla
  static String formatWithSymbol(double value) {
    return '%${format(value)}';
  }
}

/// Tarih formatlama yardımcı sınıfı
class DateTimeFormatter {
  /// Tarih ve saat formatla: 01.12.2024 14:30
  static String format(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
  }

  /// Sadece tarih formatla: 01.12.2024
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy').format(dateTime);
  }

  /// Sadece saat formatla: 14:30
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }
}
