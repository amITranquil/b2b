import 'dart:math';

String generateGuid() {
  final random = Random();
  const String hexDigits = "0123456789abcdef";
  final List<String> uuid = List.filled(36, '', growable: false);

  // Set version 4 UUID format
  for (int i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      uuid[i] = '-';
    } else if (i == 14) {
      uuid[i] = '4'; // Version 4 UUID
    } else if (i == 19) {
      uuid[i] = hexDigits[(random.nextInt(4) + 8)]; // Variant
    } else {
      final int digit = random.nextInt(16);
      uuid[i] = hexDigits[digit];
    }
  }

  return uuid.join();
}
