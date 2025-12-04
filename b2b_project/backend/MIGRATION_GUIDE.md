# PIN Authentication Migration Guide

## Yapılan Değişiklikler

### 1. Database Değişiklikleri

#### Yeni Model: `AppSetting`
- Uygulama ayarlarını database'de saklamak için yeni tablo eklendi
- PIN kodu artık database'den kontrol ediliyor
- Backend'den PIN değiştirilebilir

**Konum:** `Models/AppSetting.cs`

#### Database Context Güncellemesi
- `ApplicationDbContext.cs`'e `AppSettings` DbSet eklendi
- Initial seed data eklendi:
  - CatalogPin: "1234"
  - SessionDurationHours: "1"

### 2. Backend API Değişiklikleri

#### AuthController Güncellemeleri
- Database bağlantısı eklendi
- `verify-pin` endpoint'i database'den PIN kontrolü yapıyor
- Yeni endpoint'ler:
  - `POST /api/auth/update-pin` - PIN değiştirme
  - `GET /api/auth/get-current-pin-masked` - Maskeli PIN görüntüleme

### 3. Frontend Değişiklikleri

#### AuthService Güncellemesi
- PIN kontrolü artık backend'e HTTP isteği gönderiyor
- Async/await pattern kullanılıyor
- `verifyPin()` artık `Future<bool>` döndürüyor

#### CatalogScreen Güncellemesi
- `_verifyPin()` async yapıldı
- Loading state eklendi
- Renkli snackbar mesajları (yeşil/kırmızı)

## Migration Adımları

### 1. Database Migration Oluştur

```bash
cd /Users/sakinburakcivelek/flutter_and_c#/b2b/b2b_project/backend/B2BApi

# Migration oluştur
dotnet ef migrations add AddAppSettings

# Database'i güncelle
dotnet ef database update
```

### 2. Backend'i Test Et

```bash
# Backend'i başlat
dotnet run

# Test endpoint'leri:
# 1. PIN Doğrulama
curl -X POST http://localhost:5000/api/auth/verify-pin \
  -H "Content-Type: application/json" \
  -d '{"pin":"1234"}'

# 2. Maskeli PIN Görüntüleme
curl -X GET http://localhost:5000/api/auth/get-current-pin-masked

# 3. PIN Güncelleme
curl -X POST http://localhost:5000/api/auth/update-pin \
  -H "Content-Type: application/json" \
  -d '{"currentPin":"1234","newPin":"5678","updatedBy":"Admin"}'
```

### 3. Flutter Frontend'i Test Et

```bash
cd /Users/sakinburakcivelek/flutter_projects/b2b_catalog_web

# Dependencies'i güncelle (gerekirse)
flutter pub get

# Web uygulamasını çalıştır
flutter run -d chrome
```

## API Endpoint'leri

### 1. PIN Doğrulama
**POST** `/api/auth/verify-pin`

**Request:**
```json
{
  "pin": "1234"
}
```

**Response (Başarılı):**
```json
{
  "valid": true,
  "message": "PIN doğrulandı",
  "expiresAt": "2024-11-10T13:00:00Z"
}
```

**Response (Başarısız):**
```json
{
  "valid": false,
  "message": "Hatalı PIN"
}
```

### 2. PIN Güncelleme
**POST** `/api/auth/update-pin`

**Request:**
```json
{
  "currentPin": "1234",
  "newPin": "5678",
  "updatedBy": "Admin"
}
```

**Response:**
```json
{
  "success": true,
  "message": "PIN başarıyla güncellendi"
}
```

### 3. Maskeli PIN Görüntüleme
**GET** `/api/auth/get-current-pin-masked`

**Response:**
```json
{
  "length": 4,
  "masked": "1**4",
  "message": "PIN bilgisi"
}
```

## Database'den PIN Değiştirme

### Yöntem 1: API Kullanarak (Önerilen)
```bash
curl -X POST http://localhost:5000/api/auth/update-pin \
  -H "Content-Type: application/json" \
  -d '{"currentPin":"MEVCUT_PIN","newPin":"YENI_PIN","updatedBy":"Admin"}'
```

### Yöntem 2: Direkt SQL (Dikkatli Kullanın)
```sql
-- SQLite için
UPDATE AppSettings
SET Value = 'YENI_PIN',
    LastUpdated = datetime('now'),
    UpdatedBy = 'Admin'
WHERE Key = 'CatalogPin';

-- SQL Server için
UPDATE AppSettings
SET Value = 'YENI_PIN',
    LastUpdated = GETUTCDATE(),
    UpdatedBy = 'Admin'
WHERE [Key] = 'CatalogPin';
```

## Oturum Takibi Nasıl Çalışıyor?

1. **Frontend (Flutter)**
   - Kullanıcı PIN girer
   - `AuthService.verifyPin()` backend'e POST request gönderir
   - Başarılı ise `SharedPreferences`'te session bilgisi saklanır
   - Her sayfa yüklenişinde `isAuthenticated()` kontrol eder

2. **Backend (C#)**
   - PIN request gelir
   - Database'den `CatalogPin` ayarı okunur
   - PIN doğruysa HTTP-only cookie set edilir
   - Session süresi `SessionDurationHours` ayarından alınır

3. **Session Süresi**
   - Varsayılan: 1 saat
   - Database'den değiştirilebilir:
   ```sql
   UPDATE AppSettings
   SET Value = '2'  -- 2 saat olarak değiştir
   WHERE Key = 'SessionDurationHours';
   ```

## Güvenlik Notları

1. **HTTPS Kullanın:** Production'da mutlaka HTTPS kullanın
2. **Cookie Secure Flag:** `AuthController.cs` içinde `Secure = true` yapın
3. **PIN Karmaşıklığı:** Daha güçlü PIN'ler kullanın (6+ karakter)
4. **Rate Limiting:** Brute force saldırılara karşı rate limiting ekleyin
5. **Logging:** Başarısız PIN denemelerini logluyor

## Troubleshooting

### Problem: Migration hatası
```bash
# Migration'ları sıfırla
dotnet ef database drop
dotnet ef migrations remove
dotnet ef migrations add InitialCreate
dotnet ef database update
```

### Problem: PIN doğrulanamıyor
```bash
# Database'de PIN'i kontrol et
sqlite3 your_database.db
> SELECT * FROM AppSettings WHERE Key = 'CatalogPin';
```

### Problem: CORS hatası
`Program.cs` içinde CORS ayarlarını kontrol edin:
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter",
        policy => policy.WithOrigins("http://localhost:*")
                       .AllowAnyMethod()
                       .AllowAnyHeader()
                       .AllowCredentials());
});
```

## Gelecek İyileştirmeler

- [ ] JWT Token authentication
- [ ] Rate limiting middleware
- [ ] PIN şifreleme (hash)
- [ ] Multi-factor authentication
- [ ] Audit logging (tüm PIN değişikliklerini kaydet)
- [ ] Admin panel için ayrı endpoint
