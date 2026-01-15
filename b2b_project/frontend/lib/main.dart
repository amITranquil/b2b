import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/quotes_screen.dart';
import 'services/theme_service.dart';
import 'widgets/skeleton_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await dotenv.load(fileName: ".env");
    await _themeService.loadThemePreference();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _themeService.isDarkMode,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'URLA TEKNİK - B2B Yönetim Sistemi',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr', 'TR'),
            Locale('en', 'US'),
          ],
          locale: const Locale('tr', 'TR'),
          initialRoute: '/',
          routes: {
            '/': (context) => _isInitialized
                ? const HomeScreen()
                : const Scaffold(body: SkeletonLoader(itemCount: 30)),
            '/catalog': (context) => const CatalogScreen(),
            '/quotes': (context) => const QuotesScreen(),
          },
        );
      },
    );
  }
}
