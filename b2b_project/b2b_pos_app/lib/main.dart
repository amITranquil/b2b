// lib/main.dart - B2B POS Application
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const B2BPosApp());
}

class B2BPosApp extends StatefulWidget {
  const B2BPosApp({super.key});

  @override
  State<B2BPosApp> createState() => _B2BPosAppState();
}

class _B2BPosAppState extends State<B2BPosApp> {
  bool _isDarkMode = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
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
      title: 'B2B POS',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Light Theme
      theme: ThemeData.light(useMaterial3: true).copyWith(
        primaryColor: Colors.blue[700],
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: Colors.blue[400],
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),

      home: HomeScreen(
        onToggleTheme: toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}
