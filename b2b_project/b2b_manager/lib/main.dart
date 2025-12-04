// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/products_screen.dart';
import 'core/di/service_locator.dart';

void main() {
  // Initialize Dependency Injection
  ServiceLocator().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B2B Manager',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        // Özel dark mode renk ayarları
        cardTheme: const CardTheme(
          color: Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFF2D2D2D),
          filled: true,
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey[700]!,
            ),
          ),
        ),
      ),
      home: const ProductsScreen(),
    );
  }
}
