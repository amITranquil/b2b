import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../config/api_config.dart';
import 'quotes_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _themeService.loadThemePreference();
    _checkAuth();
    _loadProducts();
  }

  Future<void> _checkAuth() async {
    final isAuth = await _authService.isAuthenticated();
    setState(() {
      _isAuthenticated = isAuth;
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products.where((p) => !p.isDeleted).toList();
        _filteredProducts = _products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ürünler yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  String _toUpperCaseTurkish(String text) {
    // Türkçe karakterleri koruyarak büyük harfe çevir
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ş', 'Ş')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _products;
      });
      return;
    }

    final upperQuery = _toUpperCaseTurkish(query);
    setState(() {
      _filteredProducts = _products.where((product) {
        return _toUpperCaseTurkish(product.name).contains(upperQuery) ||
            _toUpperCaseTurkish(product.productCode).contains(upperQuery);
      }).toList();
    });
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
        const SnackBar(content: Text('PIN doğrulanıyor...'), duration: Duration(seconds: 1)),
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
          const SnackBar(content: Text('✓ Giriş başarılı'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✗ Hatalı PIN'), backgroundColor: Colors.red),
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
        const SnackBar(content: Text('Tüm alanları doldurun'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN en az 4 karakter olmalıdır'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni PIN\'ler eşleşmiyor'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (currentPin == newPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni PIN eskisiyle aynı olamaz'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Loading göster
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN değiştiriliyor...'), duration: Duration(seconds: 1)),
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
          const SnackBar(content: Text('✓ PIN başarıyla değiştirildi'), backgroundColor: Colors.green),
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

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    // Theme artık MaterialApp seviyesinde yönetiliyor
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('URLA TEKNİK - Ürün Kataloğu'),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.description),
              tooltip: 'Teklifler',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuotesScreen()),
                );
              },
            ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Açık Tema' : 'Koyu Tema',
            onPressed: _themeService.toggleTheme,
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
              tooltip: 'Detayları Göster',
              onPressed: _showPinDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  text: _toUpperCaseTurkish(newValue.text),
                  selection: newValue.selection,
                );
              }),
            ],
            decoration: InputDecoration(
              labelText: 'Ürün Ara',
              hintText: 'Ürün adı veya kodu ile arama yapın',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterProducts('');
                      },
                    )
                  : null,
            ),
            onChanged: _filterProducts,
          ),
        ),
        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(child: Text('Ürün bulunamadı'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount;
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth > 800) {
                      crossAxisCount = 3;
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 2;
                    } else {
                      crossAxisCount = 1;
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(_filteredProducts[index], isDarkMode);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, bool isDarkMode) {
    final imageUrl = ApiConfig.getImageUrl(product.localImagePath ?? product.imageUrl);

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 64),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 64),
                  ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    product.productCode,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    product.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                  ),
                  const Spacer(),
                  if (!_isAuthenticated) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            'Satış Fiyatı',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                          SelectableText(
                            _formatCurrency(product.salePriceIncludingVat),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.green[300] : Colors.green[700],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _buildDetailRow('Liste Fiyatı', product.listPrice, isDarkMode),
                    const SizedBox(height: 4),
                    _buildDetailRow('Alış (KDV Hariç)', product.buyPriceExcludingVat, isDarkMode),
                    const SizedBox(height: 4),
                    _buildDetailRow('Alış (KDV Dahil)', product.buyPriceIncludingVat, isDarkMode),
                    const SizedBox(height: 4),
                    _buildDetailRow('Satış (KDV Hariç)', product.salePriceExcludingVat, isDarkMode),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            'Satış (KDV Dahil)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                          SelectableText(
                            _formatCurrency(product.salePriceIncludingVat),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.green[300] : Colors.green[700],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.orange[900]?.withValues(alpha: 0.3) : Colors.orange[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              'İskonto: %${((product.discount1 + product.discount2 + product.discount3)).toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.orange[300] : Colors.orange[700],
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.blue[900]?.withValues(alpha: 0.3) : Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              'Kar: %${product.marginPercentage.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SelectableText(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        SelectableText(
          _formatCurrency(value),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: isDarkMode ? Colors.grey[200] : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
