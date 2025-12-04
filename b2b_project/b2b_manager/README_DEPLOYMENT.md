# B2B Manager - Deployment Rehberi

## Yapılan Değişiklikler (2025-11-08)

### ✅ Flutter Uygulaması
- **API URL değiştirildi**: `localhost:5042` → `192.168.1.8:5000`
- **Tüm hard-coded URL'ler temizlendi**
- **Merkezi config dosyası**: `lib/config/api_config.dart`
- Görsel URL'leri de güncellendi

### ✅ Backend API
- **Port değiştirildi**: `5042` → `5000`
- **Network binding**: `0.0.0.0` (tüm interface'lerden erişilebilir)
- CORS ayarları güncellendi

## Windows Build Alma

Mac'te Windows build alınamaz. Windows bilgisayarda şu adımları takip edin:

```bash
# 1. Flutter SDK'sının kurulu olduğunu doğrulayın
flutter doctor

# 2. Projeyi Windows bilgisayara kopyalayın
# Git ile ya da manuel kopyalama

# 3. Proje klasörüne gidin
cd b2b_manager

# 4. Bağımlılıkları yükleyin
flutter pub get

# 5. Windows build alın
flutter build windows --release

# Build çıktısı:
# build/windows/x64/runner/Release/
```

## Çalıştırma

### Backend (Windows Server - 192.168.1.8)

```bash
cd B2BApi
dotnet run
```

Backend artık **http://192.168.1.8:5000** üzerinde çalışacak.

### Flutter App (Windows Client)

Build edildikten sonra:
```
build/windows/x64/runner/Release/b2b_manager.exe
```

Ya da geliştirme modunda:
```bash
flutter run -d windows
```

## Network Yapılandırması

### Sunucu (192.168.1.8)
- Backend API: Port 5000
- Firewall: 5000 portunu açın
- Static IP: 192.168.1.8 olarak yapılandırıldığından emin olun

### Client Bilgisayarlar
- Sunucuya erişebilmeli (ping 192.168.1.8)
- Ağda olmalı

## Firewall Ayarları (Windows Server)

```powershell
# PowerShell (Admin) ile çalıştırın
New-NetFirewallRule -DisplayName "B2B API Port 5000" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
```

## Sorun Giderme

### "Connection Refused" Hatası
1. Backend'in çalıştığını kontrol edin: `curl http://192.168.1.8:5000/api/products`
2. Firewall ayarlarını kontrol edin
3. Sunucunun IP adresinin doğru olduğundan emin olun

### IP Adresi Değiştirme

Eğer sunucu IP'si farklıysa, sadece bu dosyayı değiştirin:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://SUNUCU_IP:5000';
  // ...
}
```

Sonra yeniden build alın.

## Geliştirme Notları

- **macOS build**: `flutter build macos --release`
- **Windows build**: `flutter build windows --release` (sadece Windows'ta)
- **Development**: `flutter run -d windows` veya `flutter run -d macos`

## Dosya Yapısı

```
b2b_manager/
├── lib/
│   ├── config/
│   │   └── api_config.dart      # ⭐ API yapılandırması
│   ├── services/
│   │   └── api_service.dart      # API servisi
│   └── ...
├── build/                        # Build çıktıları
│   └── windows/
│       └── x64/runner/Release/   # ⭐ Windows executable
└── BUILD_INSTRUCTIONS.md         # Detaylı talimatlar
```

## Backend Deployment (Raspberry Pi / Windows Server)

### Raspberry Pi Zero 2W
```bash
# .NET SDK kurulumu
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0 --runtime aspnetcore

# Backend publish
dotnet publish -c Release -r linux-arm

# Çalıştırma
dotnet B2BApi.dll --urls "http://0.0.0.0:5000"
```

### Windows Server
```powershell
# Backend çalıştırma
cd B2BApi
dotnet run --urls "http://0.0.0.0:5000"

# Production için Windows Service olarak kurulabilir
```

## Web Kataloğu

Web kataloğu backend ile birlikte gelir:
- **URL**: http://192.168.1.8:5000
- **PIN**: 1234 (AuthController.cs'de değiştirilebilir)

Mobil ve desktop tarayıcılarda çalışır.
