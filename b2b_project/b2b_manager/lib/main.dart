// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/products_screen.dart';
import 'core/di/service_locator.dart';

void main() {
  // Initialize Dependency Injection
  ServiceLocator().init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true; // Default: Dark mode
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? true; // Default true
      _isInitialized = true;
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'B2B Manager',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Light Theme
      theme: ThemeData.light(useMaterial3: true).copyWith(
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.grey[100],
          filled: true,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
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

      // Home page
      home: HomeScreen(
        onToggleTheme: toggleTheme,
        isDarkMode: _isDarkMode,
      ),

      // Route generator
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/products':
            return MaterialPageRoute(
              builder: (context) => ProductsScreen(
                onToggleTheme: toggleTheme,
                isDarkMode: _isDarkMode,
                initialTabIndex: 0,
              ),
            );
          case '/manual-products':
            return MaterialPageRoute(
              builder: (context) => ProductsScreen(
                onToggleTheme: toggleTheme,
                isDarkMode: _isDarkMode,
                initialTabIndex: 0,
                showOnlyManual: true,
              ),
            );
          case '/quotes':
            return MaterialPageRoute(
              builder: (context) => ProductsScreen(
                onToggleTheme: toggleTheme,
                isDarkMode: _isDarkMode,
                initialTabIndex: 1,
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}
