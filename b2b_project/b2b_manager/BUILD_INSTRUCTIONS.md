# B2B Manager - Build Talimatları

## API Yapılandırması

Uygulama şu anda **`http://192.168.1.8:5000`** API adresine bağlanacak şekilde yapılandırıldı.

API adresi değiştirilmek istenirse: `/Users/sakinburakcivelek/flutter_projects/b2b_manager/lib/config/api_config.dart`

## Windows Build (Sadece Windows'ta)

Windows build almak için Windows bilgisayarda şu adımları takip edin:

### Gereksinimler:
1. Flutter SDK (3.0+)
2. Visual Studio 2022 (Desktop development with C++)

### Build Komutları:

```bash
# Projeyi Windows'a kopyalayın veya Git ile çekin

# Bağımlılıkları yükleyin
flutter pub get

# Windows build'ini alın
flutter build windows --release

# Build çıktısı:
# build/windows/x64/runner/Release/
```

### Build Çıktısı:

```
build/windows/x64/runner/Release/
├── b2b_manager.exe          # Ana uygulama
├── flutter_windows.dll       # Flutter runtime
├── data/                     # Uygulama verileri
│   └── icudtl.dat
└── ...diğer DLL'ler
```

Bu klasörün tamamını kopyalayıp başka bir Windows bilgisayara taşıyabilirsiniz.

## macOS Build (Mac'te)

```bash
flutter build macos --release
```

Build çıktısı: `build/macos/Build/Products/Release/b2b_manager.app`

## Geliştirme Modunda Çalıştırma

### macOS'ta:
```bash
flutter run -d macos
```

### Windows'ta:
```bash
flutter run -d windows
```

## API Sunucusu

Backend API'nin **192.168.1.8:5000** adresinde çalışıyor olması gerekir.

Backend sunucuyu başlatmak için:
```bash
cd /Users/sakinburakcivelek/flutter_and_c#/b2b/b2b_project/backend/B2BApi
dotnet run
```

Port 5000'i dinleyecek şekilde yapılandırın (Program.cs'de):
```csharp
app.Run("http://0.0.0.0:5000");
```

## Sorun Giderme

### "Sunucuya bağlanılamadı" hatası:
1. Backend API'nin çalıştığından emin olun
2. 192.168.1.8 IP adresinin doğru olduğunu kontrol edin
3. Firewall'un 5000 portunu engellemediğini kontrol edin

### Windows build hatası:
- Visual Studio 2022'nin kurulu olduğundan emin olun
- "Desktop development with C++" workload'ının yüklü olduğunu kontrol edin
- `flutter doctor` komutunu çalıştırarak eksikleri kontrol edin

## Değişiklik Geçmişi

- **2025-11-08**: API URL'si `localhost:5042` → `192.168.1.8:5000` olarak değiştirildi
- Tüm hard-coded URL'ler `api_config.dart` dosyasına taşındı
