# B2B Catalog Web - Ürün Kataloğu

Flutter Web tabanlı ürün kataloğu uygulaması. Adaptive ve responsive tasarım ile tüm cihazlarda çalışır.

## Özellikler

- **Default Görünüm**: Sadece satış fiyatı (KDV dahil) gösterilir
- **PIN Korumalı Detaylı Görünüm**: PIN (1234) ile tüm fiyatlar ve kar marjı görünür
- **Responsive Tasarım**: Mobil, tablet ve desktop cihazlarda otomatik uyum
- **Arama Fonksiyonu**: Ürün adı veya kodu ile arama
- **Oturum Yönetimi**: 1 saat süreyle aktif oturum

## API Yapılandırması

Uygulama `http://192.168.1.8:5000` adresindeki backend API'yi kullanır.

API adresi değiştirilmek istenirse: `lib/config/api_config.dart`

```dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.8:5000';
  // ...
}
```

## Çalıştırma

### Geliştirme Modunda

```bash
# Chrome'da çalıştır
flutter run -d chrome

# Edge'de çalıştır
flutter run -d edge
```

### Web Build

```bash
flutter build web --release
```

Build çıktısı: `build/web/`

## Deployment

### Raspberry Pi Zero 2W

1. Web build alın:
```bash
flutter build web --release
```

2. `build/web` klasörünü sunucuya kopyalayın:
```bash
scp -r build/web/* pi@192.168.1.8:/var/www/catalog/
```

3. Backend API'nin çalıştığından emin olun (Port 5000)

### Nginx Yapılandırması (Opsiyonel)

```nginx
server {
    listen 80;
    server_name 192.168.1.8;

    root /var/www/catalog;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy
    location /api/ {
        proxy_pass http://localhost:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## PIN Sistemi

- **Default PIN**: `1234`
- **Oturum Süresi**: 1 saat
- **Depolama**: SharedPreferences (browser local storage)

PIN değiştirmek için: `lib/services/auth_service.dart`

## Dosya Yapısı

```
lib/
├── config/
│   └── api_config.dart          # API yapılandırması
├── models/
│   └── product.dart             # Ürün modeli
├── screens/
│   └── catalog_screen.dart      # Ana katalog ekranı
├── services/
│   ├── api_service.dart         # API servisi
│   └── auth_service.dart        # Kimlik doğrulama servisi
└── main.dart                    # Uygulama giriş noktası
```

## Responsive Breakpoints

- **Mobile**: < 600px (1 sütun)
- **Tablet**: 600px - 800px (2 sütun)
- **Desktop**: 800px - 1200px (3 sütun)
- **Large Desktop**: > 1200px (4 sütun)

## Sorun Giderme

### "Ürünler yüklenemedi" hatası

1. Backend API'nin çalıştığından emin olun
2. API adresini kontrol edin: `lib/config/api_config.dart`
3. Network bağlantısını kontrol edin
4. CORS ayarlarını kontrol edin (backend)

### PIN çalışmıyor

1. Browser'ın local storage'ı desteklediğinden emin olun
2. Browser cache'ini temizleyin
3. `lib/services/auth_service.dart` içinde PIN'i kontrol edin

## Güvenlik

- PIN sadece client-side kontrolü (demo amaçlı)
- Production için backend'de authentication gerekir
- HTTPS kullanın (production'da)
- robots.txt ile Google indexlemesini engelleyin
