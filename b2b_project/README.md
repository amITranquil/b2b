# B2B Ürün Yönetimi Sistemi

Bu proje, B2B web sitesinden ürün verilerini otomatik olarak çeken ve bir desktop uygulaması üzerinden yöneten tam stack bir sistemdir.

## 🏗️ Proje Yapısı

```
b2b_project/
├── backend/                 # ASP.NET Core Web API
│   └── B2BApi/
│       ├── Controllers/     # REST API endpoints
│       ├── Models/          # Veri modelleri
│       ├── Services/        # Web scraping servisleri
│       ├── Data/           # Entity Framework DbContext
│       └── Program.cs      # Uygulama başlangıç noktası
├── b2b_desktop_app/        # Flutter Desktop Uygulaması
│   ├── lib/
│   │   ├── models/         # Dart veri modelleri
│   │   ├── services/       # API servis katmanı
│   │   ├── providers/      # State management (Provider)
│   │   ├── screens/        # Uygulama ekranları
│   │   ├── widgets/        # Yeniden kullanılabilir UI bileşenleri
│   │   └── main.dart       # Flutter uygulaması giriş noktası
│   └── pubspec.yaml        # Flutter bağımlılıkları
└── README.md               # Bu dosya
```

## 🚀 Özellikler

### Backend (ASP.NET Core Web API)
- **Web Scraping**: HtmlAgilityPack ile B2B sitesinden ürün verilerini otomatik çekme
- **SQLite Veritabanı**: Entity Framework Core ile veri yönetimi
- **REST API**: Ürün CRUD işlemleri ve arama
- **Kar Marjı Hesaplama**: Dinamik fiyat hesaplaması
- **Rate Limiting**: 2 saniye bekleme ile güvenli scraping

### Frontend (Flutter Desktop)
- **Cross-Platform Desktop**: Windows, macOS, Linux desteği
- **Material Design 3**: Modern ve kullanıcı dostu arayüz
- **Dark/Light Theme**: Sistem teması ile uyumlu
- **Gerçek Zamanlı Arama**: Ürün kodu, isim ve kategoriye göre filtreleme
- **Kar Marjı Yönetimi**: Ürün detayında kar marjı güncelleme
- **Pull-to-Refresh**: Elle yenileme desteği
- **State Management**: Provider ile merkezi durum yönetimi

## 📋 Gereksinimler

### Backend
- .NET 8.0 SDK
- Visual Studio Code veya Visual Studio

### Frontend
- Flutter SDK (3.6.1+)
- Dart SDK
- Desktop development desteği

## 🛠️ Kurulum

### 1. Backend Kurulumu

```bash
# Backend dizinine git
cd backend/B2BApi

# Bağımlılıkları yükle
dotnet restore

# Veritabanını oluştur (otomatik)
dotnet run
```

Backend varsayılan olarak `http://localhost:5042` portunda çalışır.

### 2. Frontend Kurulumu

```bash
# Frontend dizinine git
cd b2b_desktop_app

# Flutter bağımlılıklarını yükle
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

## 🔧 Yapılandırma

### Backend Ayarları
`appsettings.json` dosyasında:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=b2b_products.db"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
```

### Frontend Ayarları
`lib/services/api_service.dart` dosyasında API URL'ini güncelleyin:
```dart
static const String baseUrl = 'http://localhost:5042/api';
```

## 📊 Veritabanı Şeması

### Products Tablosu
| Alan | Tip | Açıklama |
|------|-----|----------|
| Id | int | Otomatik artan birincil anahtar |
| ProductCode | string(50) | Ürün kodu (unique) |
| Name | string(200) | Ürün adı |
| BuyPrice | decimal(18,2) | Alış fiyatı |
| MyPrice | decimal(18,2) | Satış fiyatı |
| Stock | int | Stok miktarı |
| Category | string(100) | Ürün kategorisi |
| MarginPercentage | decimal(5,2) | Kar marjı yüzdesi |
| LastUpdated | datetime | Son güncelleme tarihi |

## 🌐 API Endpoints

### Products Controller
- `GET /api/products` - Tüm ürünleri listele
- `GET /api/products/{code}` - Belirli ürünü getir
- `GET /api/products/search/{term}` - Ürün ara
- `PUT /api/products/{code}/margin` - Kar marjını güncelle
- `POST /api/products/scrape` - Manuel scraping başlat

## 🖥️ Uygulama Ekranları

### Ana Ekran
- Ürün listesi (liste/kart görünümü)
- Gerçek zamanlı arama
- Pull-to-refresh
- Ürün detayına geçiş

### Ürün Detay Ekranı
- Ürün bilgileri görüntüleme
- Kar marjı güncelleme
- Fiyat hesaplaması
- Stok durumu

### Ayarlar Ekranı
- Manuel scraping başlatma
- API bağlantı testi
- Tema ayarları
- Uygulama bilgileri

## 🔒 Güvenlik

- **Rate Limiting**: Web scraping işlemlerinde 2 saniye bekleme
- **Input Validation**: Tüm kullanıcı girdilerinin doğrulanması
- **Error Handling**: Kapsamlı hata yönetimi
- **CORS**: Sadece frontend uygulamasına izin

## 🚦 Kullanım

1. **Backend'i Başlatın**: `dotnet run` komutu ile API'yi çalıştırın
2. **Frontend'i Başlatın**: `flutter run` ile desktop uygulamasını açın
3. **İlk Scraping**: Ayarlar sayfasından "Veri Senkronizasyonu Başlat" butonuna tıklayın
4. **Ürünleri Görüntüleyin**: Ana sayfada ürünler listelenecek
5. **Kar Marjı Ayarlayın**: Ürün detayında kar marjlarını güncelleyin

## 🐛 Bilinen Sorunlar

- Scraping işlemi sırasında ağ bağlantısı problemi olursa işlem durabilir
- Desktop tema değişiklikleri uygulama yeniden başlatıldığında aktif olur

## 📝 Katkıda Bulunma

1. Projeyi fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## 📄 Lisans

Bu proje özel kullanım içindir.

## 📞 İletişim

Sorularınız için issue açabilir veya e-posta gönderebilirsiniz.