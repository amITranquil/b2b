# B2B Desktop App

B2B Ürün Yönetimi Flutter Desktop Uygulaması

## Başlangıç

Bu proje B2B ürün yönetimi için geliştirilmiş bir Flutter desktop uygulamasıdır.

## Çalıştırma

```bash
# Bağımlılıkları yükle
flutter pub get

# Desktop desteğini etkinleştir
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop

# Uygulamayı çalıştır
flutter run -d macos    # macOS için
flutter run -d windows  # Windows için
flutter run -d linux    # Linux için
```

## Özellikler

- Ürün listesi ve arama
- Ürün detay görüntüleme
- Kar marjı yönetimi
- Veri senkronizasyonu
- Koyu/Açık tema desteği

Backend API'sinin çalışır durumda olması gerekir.
