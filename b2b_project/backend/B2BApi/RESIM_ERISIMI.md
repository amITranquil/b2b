# 🖼️ Resim Erişimi - Mimari Açıklama

## 📋 Mevcut Durum

### Resimler Nerede?

```
/home/dietpi/b2bapi/publish/wwwroot/images/
  ├── P.12345.jpg
  ├── P.67890.jpg
  └── ...
```

### Nasıl Erişiliyor?

**1. Flutter Desktop App:**
```dart
// lib/services/api_service.dart
static const String baseUrl = 'http://192.168.1.8:5000/api';

// lib/widgets/product_card.dart
Image.network('http://192.168.1.8:5000/${product.localImagePath}')
// Örnek: http://192.168.1.8:5000/images/P.12345.jpg
```

**2. Web App (Browser):**
```javascript
// config.js
apiUrl: 'https://urlateknik.com'  // Production
// Resim: https://urlateknik.com/hvk/api/images/P.12345.jpg (lighttpd proxy ile)
```

## 🏗️ Mimari

```
┌─────────────────────────────────────────────────────────────┐
│                     İSTEKLER                                │
└─────────────────────────────────────────────────────────────┘

Flutter App (Desktop)          Web App (Browser)
     │                              │
     │ http://192.168.1.8:5000/     │ https://urlateknik.com/hvk/api/
     │        images/P.xxx.jpg       │        images/P.xxx.jpg
     │                              │
     ▼                              ▼
┌──────────────┐              ┌──────────────┐
│  API:5000    │◄─────────────│  lighttpd    │
│              │   Proxy      │              │
│ StaticFiles  │              │              │
│   Serve      │              │              │
└──────────────┘              └──────────────┘
     │
     ▼
/home/dietpi/b2bapi/publish/wwwroot/images/


┌─────────────────────────────────────────────────────────────┐
│                    SONUÇ                                    │
└─────────────────────────────────────────────────────────────┘

✅ Flutter App → Doğrudan API'den alır
✅ Web App → lighttpd proxy üzerinden API'den alır
✅ Tüm uygulamalar aynı resimlere erişir
```

## ⚙️ Konfigürasyon

### API (Program.cs)
```csharp
// Static file serving HER ZAMAN aktif (images için)
app.UseStaticFiles();
```

### lighttpd (/etc/lighttpd/conf-available/99-hvk.conf)
```nginx
# /hvk/api/ altındaki tüm istekler API'ye proxy edilir
$HTTP["url"] =~ "^/hvk/api/" {
    proxy.server = (
        "" => (
            ( "host" => "127.0.0.1", "port" => 5000 )
        )
    )
}
```

### Web App (config.js)
```javascript
production: {
    apiUrl: 'https://urlateknik.com'
}
```

## 📊 Erişim Örnekleri

### Ürün Verisi (Database)
```json
{
  "productCode": "P.12345",
  "name": "Musluk",
  "localImagePath": "images/P.12345.jpg"  // ← Relative path
}
```

### Flutter App İsteği
```
GET http://192.168.1.8:5000/images/P.12345.jpg
```

### Web App İsteği (Browser)
```
GET https://urlateknik.com/hvk/api/images/P.12345.jpg

↓ lighttpd proxy

GET http://localhost:5000/api/images/P.12345.jpg

↓ API StaticFiles Middleware

/home/dietpi/b2bapi/publish/wwwroot/images/P.12345.jpg
```

## 🔧 Deployment

### Resimler Dahil API Deploy
```bash
rsync -avz --progress \
    --exclude='*.db' \
    --exclude='wwwroot/*.html' \
    --exclude='wwwroot/*.js' \
    --exclude='wwwroot/*.css' \
    ./bin/Release/publish/ dietpi@192.168.1.8:/home/dietpi/b2bapi/publish/
```

**NOT:** `wwwroot/images/` klasörü **DAHİL** edilir!

## ✅ Avantajlar

1. **Tek Kaynak**: Tüm resimler bir yerde
2. **Otomatik Sync**: Scraping yeni resim eklediğinde tüm uygulamalar görür
3. **Merkezi Yönetim**: Resimler API ile birlikte deploy edilir
4. **Ölçeklenebilir**: İleride CDN eklenebilir

## 🚀 Gelecek İyileştirmeler

### CDN Ekleme (Opsiyonel)
```javascript
// config.js
production: {
    apiUrl: 'https://urlateknik.com',
    cdnUrl: 'https://cdn.urlateknik.com'  // Resimler için
}
```

### Nginx/lighttpd Cache
```nginx
# Resimleri cache'le (30 gün)
$HTTP["url"] =~ "^/hvk/api/images/" {
    expire.url = ( "" => "access plus 30 days" )
}
```

## 📝 Özet

- ✅ API `wwwroot/images/` klasörünü tutar
- ✅ API `UseStaticFiles()` ile resimleri serve eder
- ✅ Flutter app doğrudan API'den alır
- ✅ Web app lighttpd proxy üzerinden API'den alır
- ✅ Tüm uygulamalar aynı resimlere erişir
