# B2B API Backend

B2B ürün yönetimi sistemi için ASP.NET Core Web API backend'i.

## Özellikler

- **Web Scraping**: HtmlAgilityPack ile B2B sitesinden otomatik veri çekme
- **SQLite Veritabanı**: Entity Framework Core ile veri yönetimi
- **REST API**: Ürün CRUD işlemleri
- **Kar Marjı Hesaplama**: Dinamik fiyat hesaplaması
- **Rate Limiting**: Güvenli scraping için bekleme mekanizması

## Kurulum

```bash
cd B2BApi

# Bağımlılıkları yükle
dotnet restore

# Uygulamayı çalıştır
dotnet run
```

API varsayılan olarak `http://localhost:5042` portunda çalışır.

## API Endpoints

### Products
- `GET /api/products` - Tüm ürünler
- `GET /api/products/{code}` - Belirli ürün
- `GET /api/products/search/{term}` - Ürün arama
- `PUT /api/products/{code}/margin` - Kar marjı güncelleme
- `POST /api/products/scrape` - Manuel scraping

## Yapılandırma

`appsettings.json` dosyasında veritabanı bağlantı stringi:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=b2b_products.db"
  }
}
```

## Kullanılan Teknolojiler

- ASP.NET Core 8.0
- Entity Framework Core
- SQLite
- HtmlAgilityPack
- Swagger/OpenAPI