import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _pinController = TextEditingController();

  int _totalProducts = 0;
  int _totalQuotes = 0;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadStatistics();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final isAuth = await _authService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuth;
    });
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ürün sayısını al
      final products = await _apiService.getProducts();
      final activeProducts = products.where((p) => !p.isDeleted).toList();

      // Teklif sayısını al
      final quotes = await _apiService.getQuotes();

      if (mounted) {
        setState(() {
          _totalProducts = activeProducts.length;
          _totalQuotes = quotes.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔒 Detaylı Bilgi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN',
                hintText: '4 haneli PIN',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => _verifyPin(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: _verifyPin,
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text;

    // PIN doğrulama sırasında loading göster
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PIN doğrulanıyor...'),
            duration: Duration(seconds: 1)),
      );
    }

    // JWT login kullan
    final result = await _authService.login(pin);

    if (result != null && result['success'] == true) {
      setState(() {
        _isAuthenticated = true;
      });
      _pinController.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✓ Giriş başarılı'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✗ Hatalı PIN'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _logout() async {
    await _authService.logout();
    setState(() {
      _isAuthenticated = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum kapatıldı')),
      );
    }
  }

  void _showChangePinDialog() {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔐 PIN Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinController,
              decoration: const InputDecoration(
                labelText: 'Mevcut PIN',
                hintText: '4 haneli PIN',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(
                labelText: 'Yeni PIN',
                hintText: '4 haneli PIN',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Yeni PIN (Tekrar)',
                hintText: '4 haneli PIN',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: false,
              onSubmitted: (_) => _changePin(
                currentPinController.text,
                newPinController.text,
                confirmPinController.text,
                context,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _changePin(
              currentPinController.text,
              newPinController.text,
              confirmPinController.text,
              context,
            ),
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePin(
    String currentPin,
    String newPin,
    String confirmPin,
    BuildContext dialogContext,
  ) async {
    // Validasyon
    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tüm alanları doldurun'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PIN en az 4 karakter olmalıdır'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Yeni PIN\'ler eşleşmiyor'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (currentPin == newPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Yeni PIN eskisiyle aynı olamaz'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Loading göster
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PIN değiştiriliyor...'),
            duration: Duration(seconds: 1)),
      );
    }

    // PIN değiştir
    final result = await _authService.changePin(currentPin, newPin);

    // Dialog'u kapat
    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }

    // Sonucu göster
    if (mounted) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✓ PIN başarıyla değiştirildi'),
              backgroundColor: Colors.green),
        );
        // Oturumu kapat - yeni PIN ile giriş yapması için
        _logout();
      } else {
        final message = result?['message'] ?? 'PIN değiştirilemedi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✗ $message'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToPage(String route) {
    if (route == '/quotes') {
      // Teklifler için PIN zorunlu
      if (_isAuthenticated) {
        Navigator.pushNamed(context, route);
      } else {
        _showPinDialog();
      }
    } else {
      // Katalog için her zaman açılır (PIN opsiyonel - içeride fiyat kısıtlaması var)
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'URLA TEKNİK - B2B Yönetim Sistemi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Dark mode toggle
          ValueListenableBuilder<bool>(
            valueListenable: _themeService.isDarkMode,
            builder: (context, isDarkMode, child) {
              return IconButton(
                icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                tooltip: isDarkMode ? 'Açık Tema' : 'Koyu Tema',
                onPressed: () => _themeService.toggleTheme(),
              );
            },
          ),
          if (_isAuthenticated) ...[
            IconButton(
              icon: const Icon(Icons.vpn_key),
              tooltip: 'PIN Değiştir',
              onPressed: _showChangePinDialog,
            ),
            IconButton(
              icon: const Icon(Icons.lock_open),
              tooltip: 'Oturumu Kapat',
              onPressed: _logout,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.lock),
              tooltip: 'Giriş Yap',
              onPressed: _showPinDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    Colors.grey[900]!,
                    Colors.grey[850]!,
                  ]
                : [
                    Colors.blue[50]!,
                    Colors.white,
                  ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo ve Başlık
                  Icon(
                    Icons.business,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'HOŞGELDİNİZ',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'B2B Ürün ve Teklif Yönetim Sistemi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Ana Menü Kartları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Katalog Kartı
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.inventory_2,
                          title: 'Ürün Kataloğu',
                          subtitle: _isLoading
                              ? 'Yükleniyor...'
                              : '$_totalProducts Ürün',
                          color: Colors.blue,
                          onTap: () => _navigateToPage('/catalog'),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Teklifler Kartı
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.description,
                          title: 'Teklifler',
                          subtitle: _isLoading
                              ? 'Yükleniyor...'
                              : '$_totalQuotes Teklif',
                          color: Colors.green,
                          onTap: () => _navigateToPage('/quotes'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // İstatistikler
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'SİSTEM İSTATİSTİKLERİ',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatisticItem(
                                icon: Icons.inventory,
                                label: 'Toplam Ürün',
                                value: _isLoading
                                    ? '...'
                                    : _totalProducts.toString(),
                                color: Colors.blue,
                              ),
                              _StatisticItem(
                                icon: Icons.description,
                                label: 'Toplam Teklif',
                                value: _isLoading
                                    ? '...'
                                    : _totalQuotes.toString(),
                                color: Colors.green,
                              ),
                              _StatisticItem(
                                icon: Icons.cloud_done,
                                label: 'Durum',
                                value: 'Çevrimiçi',
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Text(
                    'URLA TEKNİK © 2026',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Menu Card Widget
class _MenuCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        child: Card(
          elevation: _isHovered ? 12 : 4,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color.withValues(alpha: 0.1),
                    widget.color.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 64,
                    color: widget.color,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Statistic Item Widget
class _StatisticItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}
