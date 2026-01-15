import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../providers/product_provider.dart';
import 'outdated_products_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isScrapingInProgress = false;
  String _lastScrapingResult = '';
  bool _darkMode = false;
  String _apiUrl = 'https://b2bapi.urlateknik.com:5000/api';
  final TextEditingController _apiUrlController = TextEditingController();
  bool _shouldStopScraping = false;

  // Backup state
  bool _isBackupInProgress = false;
  String _lastBackupResult = '';
  List<dynamic> _backupList = [];
  bool _isLoadingBackups = false;

  // Backend state
  String _selectedBackend = 'remote'; // 'remote' veya 'local'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Backend URL'i belirle
    final savedBackendUrl = prefs.getString('backend_url');
    String backendType = 'remote'; // default

    if (savedBackendUrl != null) {
      if (savedBackendUrl.contains('localhost')) {
        backendType = 'local';
      }
    }

    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _apiUrl = savedBackendUrl ?? 'https://b2bapi.urlateknik.com:5000/api';
      _apiUrlController.text = _apiUrl;
      _lastScrapingResult = prefs.getString('last_scraping_result') ?? '';
      _lastBackupResult = prefs.getString('last_backup_result') ?? '';
      _selectedBackend = backendType;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('api_url', _apiUrl);
  }

  Future<void> _startScraping() async {
    // Önce login bilgilerini al
    final credentials = await _getLoginCredentials();
    if (credentials == null) {
      return; // Kullanıcı iptal etti
    }

    setState(() {
      _isScrapingInProgress = true;
      _shouldStopScraping = false;
      _lastScrapingResult = '';
    });

    try {
      await context.read<ProductProvider>().startScraping(credentials['email']!, credentials['password']!);
      
      final result = _shouldStopScraping 
        ? 'Scraping kullanıcı tarafından durduruldu - ${DateTime.now().toString().substring(0, 19)}'
        : 'Scraping başarıyla tamamlandı - ${DateTime.now().toString().substring(0, 19)}';
      setState(() {
        _lastScrapingResult = result;
      });

      // Sonucu kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_scraping_result', result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_shouldStopScraping ? 'Scraping işlemi durduruldu!' : 'Scraping işlemi başarıyla tamamlandı!'),
            backgroundColor: _shouldStopScraping ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorResult = 'Scraping hatası: $e - ${DateTime.now().toString().substring(0, 19)}';
      setState(() {
        _lastScrapingResult = errorResult;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scraping hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScrapingInProgress = false;
          _shouldStopScraping = false;
        });
      }
    }
  }

  void _stopScraping() async {
    setState(() {
      _shouldStopScraping = true;
    });
    
    try {
      await context.read<ProductProvider>().stopScraping();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scraping durduruldu!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Durdurma hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testApiConnection() async {
    try {
      final isConnected = await context.read<ProductProvider>().testApiConnection();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConnected ? 'API bağlantısı başarılı!' : 'API bağlantısı başarısız!',
            ),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı testi hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateApiUrl() {
    setState(() {
      _apiUrl = _apiUrlController.text.trim();
    });
    _saveSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API URL güncellendi. Uygulamayı yeniden başlatın.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Backend değiştir
  Future<void> _changeBackend(String backendType) async {
    setState(() {
      _selectedBackend = backendType;
    });

    String newUrl;
    if (backendType == 'remote') {
      newUrl = 'https://b2bapi.urlateknik.com:5000/api';
    } else {
      newUrl = 'http://localhost:5000/api';
    }

    try {
      // Provider referansını önce al
      final provider = context.read<ProductProvider>();
      await provider.changeBackend(newUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backendType == 'remote'
                ? '✅ Uzak backend seçildi (Production)'
                : '✅ Lokal backend seçildi (Development)',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend değiştirme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Backup metodları
  Future<void> _createBackup() async {
    setState(() {
      _isBackupInProgress = true;
      _lastBackupResult = '';
    });

    try {
      final result = await context.read<ProductProvider>().createBackup();

      final successResult = 'Backup oluşturuldu: ${result['backupFile']} (${result['size']}) - ${DateTime.now().toString().substring(0, 19)}';
      setState(() {
        _lastBackupResult = successResult;
      });

      // Sonucu kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_result', successResult);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup başarıyla oluşturuldu!\n${result['backupFile']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Backup listesini yenile
      await _loadBackups();
    } catch (e) {
      final errorResult = 'Backup hatası: $e - ${DateTime.now().toString().substring(0, 19)}';
      setState(() {
        _lastBackupResult = errorResult;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackupInProgress = false;
        });
      }
    }
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoadingBackups = true;
    });

    try {
      final result = await context.read<ProductProvider>().listBackups();

      if (mounted) {
        setState(() {
          _backupList = result['backups'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup listesi yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBackups = false;
        });
      }
    }
  }

  Future<void> _downloadBackup(String fileName) async {
    try {
      // Dosya kaydetme yerini seç
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Backup Kaydet',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['db', 'gz'],
      );

      if (outputPath == null) {
        // Kullanıcı iptal etti
        return;
      }

      if (!mounted) return;

      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Backup indiriliyor...'),
            ],
          ),
        ),
      );

      // Provider referansını önce al
      final provider = context.read<ProductProvider>();

      // Backup'ı indir
      final bytes = await provider.downloadBackup(fileName);

      // Dosyaya yaz
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      // Loading'i kapat
      Navigator.pop(context);

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup başarıyla indirildi!\n$outputPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Loading varsa kapat
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Hata mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup indirme hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showBackupListDialog() async {
    await _loadBackups();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Listesi'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: _isLoadingBackups
              ? const Center(child: CircularProgressIndicator())
              : _backupList.isEmpty
                  ? const Center(
                      child: Text('Henüz backup oluşturulmamış'),
                    )
                  : ListView.builder(
                      itemCount: _backupList.length,
                      itemBuilder: (context, index) {
                        final backup = _backupList[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.backup, color: Colors.blue),
                            title: Text(
                              backup['fileName'] ?? '',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Boyut: ${backup['sizeMB']} MB'),
                                Text('Tarih: ${backup['createdAt']}'),
                                Text('${backup['age']}', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.download, color: Colors.green),
                              tooltip: 'İndir',
                              onPressed: () {
                                Navigator.pop(context); // Dialog'u kapat
                                _downloadBackup(backup['fileName']);
                              },
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          if (_backupList.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadBackups();
              },
              child: const Text('Yenile'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scraping Ayarları
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Veri Senkronizasyonu',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'B2B sisteminden ürün verilerini çeker ve yerel veritabanını günceller.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_isScrapingInProgress) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startScraping,
                          icon: const Icon(Icons.sync),
                          label: const Text('Veri Senkronizasyonu Başlat'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              label: const Text('Senkronizasyon yapılıyor...'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _stopScraping,
                            icon: const Icon(Icons.stop),
                            label: const Text('Durdur'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_lastScrapingResult.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lastScrapingResult.contains('hata')
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _lastScrapingResult.contains('hata')
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _lastScrapingResult,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _lastScrapingResult.contains('hata')
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Database Backup
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.backup,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Veritabanı Yedekleme',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Veritabanının manuel yedeğini oluşturun ve mevcut yedekleri görüntüleyin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isBackupInProgress ? null : _createBackup,
                            icon: _isBackupInProgress
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_circle),
                            label: Text(_isBackupInProgress ? 'Backup oluşturuluyor...' : 'Backup Oluştur'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isBackupInProgress ? null : _showBackupListDialog,
                            icon: const Icon(Icons.list),
                            label: const Text('Backup Listesi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_lastBackupResult.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lastBackupResult.contains('hata')
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _lastBackupResult.contains('hata')
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _lastBackupResult,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _lastBackupResult.contains('hata')
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ürün Yönetimi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ürün Yönetimi',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Eski ve kullanılmayan ürünleri yönetin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OutdatedProductsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.warning_amber),
                        label: const Text('Eski Ürünleri Görüntüle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Backend Sunucusu Seçimi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Backend Sunucusu',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'API bağlantısı için backend sunucusunu seçin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Uzak Backend
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedBackend == 'remote'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: _selectedBackend == 'remote' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RadioListTile<String>(
                        title: const Text('🌐 Uzak (Production)'),
                        subtitle: const Text(
                          'https://b2bapi.urlateknik.com:5000\nNormal kullanım için',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: 'remote',
                        groupValue: _selectedBackend,
                        onChanged: (value) {
                          if (value != null) {
                            _changeBackend(value);
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Lokal Backend
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedBackend == 'local'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: _selectedBackend == 'local' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RadioListTile<String>(
                        title: const Text('💻 Lokal (Development)'),
                        subtitle: const Text(
                          'http://localhost:5000\nScraping yaparken kullanın',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: 'local',
                        groupValue: _selectedBackend,
                        onChanged: (value) {
                          if (value != null) {
                            _changeBackend(value);
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Aktif backend bilgisi
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedBackend == 'remote'
                                  ? 'Aktif: Uzak Backend (Production)'
                                  : 'Aktif: Lokal Backend (Development)',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // API Ayarları
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.api,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'API Ayarları',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiUrlController,
                      decoration: InputDecoration(
                        labelText: 'API URL',
                        hintText: 'https://b2bapi.urlateknik.com:5000/api',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          onPressed: _updateApiUrl,
                          icon: const Icon(Icons.save),
                          tooltip: 'Kaydet',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testApiConnection,
                            icon: const Icon(Icons.wifi_protected_setup),
                            label: const Text('Bağlantıyı Test Et'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Uygulama Ayarları
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings_applications,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Uygulama Ayarları',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Koyu Tema'),
                      subtitle: const Text('Uygulamayı koyu temada kullan'),
                      value: _darkMode,
                      onChanged: (value) {
                        setState(() {
                          _darkMode = value;
                        });
                        _saveSettings();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tema ayarı kaydedildi. Değişiklik için uygulamayı yeniden başlatın.'),
                          ),
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Uygulama Bilgileri
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Uygulama Bilgileri',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Uygulama Adı', 'B2B Ürün Yönetimi'),
                    _buildInfoRow('Versiyon', '1.0.0'),
                    _buildInfoRow('Platform', 'Flutter Desktop'),
                    _buildInfoRow('API Backend', 'ASP.NET Core Web API'),
                    _buildInfoRow('Veritabanı', 'SQLite'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Danger Zone
            Card(
              color: Colors.red.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tehlikeli İşlemler',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bu işlemler geri alınamaz. Dikkatli olun!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showClearDataDialog,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Tüm Verileri Temizle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _getLoginCredentials() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    // Kayıtlı credentials'ları yükle
    final prefs = await SharedPreferences.getInstance();
    emailController.text = prefs.getString('b2b_email') ?? '';
    passwordController.text = prefs.getString('b2b_password') ?? '';

    return showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giriş Bilgileri'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scraping işlemi için B2B giriş bilgilerinizi girin:'),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
                // Credentials'ları kaydet
                await prefs.setString('b2b_email', emailController.text);
                await prefs.setString('b2b_password', passwordController.text);
                
                Navigator.pop(context, {
                  'email': emailController.text,
                  'password': passwordController.text,
                });
              }
            },
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Verileri Temizle'),
        content: const Text(
          'Bu işlem tüm ürün verilerini silecektir. Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement clear data functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu özellik henüz implement edilmedi'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}