# URLA TEKNİK - Web Kataloğu

Raspberry Pi Zero 2W için optimize edilmiş, hafif ve responsive B2B ürün kataloğu.

## Özellikler

- ✅ **Responsive Tasarım**: Mobil, tablet ve desktop cihazlarda mükemmel görünüm
- ✅ **Hafif**: Vanilla JS, framework yükü yok, RPi Zero 2W için optimize
- ✅ **PIN Korumalı Detaylar**: Sadece satış fiyatı gösterir, PIN ile alış fiyatları ve kar marjlarını açar
- ✅ **Session Bazlı**: 1 saat süreyle aktif kalır
- ✅ **Google Indexleme Koruması**: robots.txt ile korunmuş
- ✅ **Arama**: Ürün kodu ve isimle hızlı arama

## Dosya Yapısı

```
wwwroot/
├── index.html      # Ana sayfa
├── styles.css      # Responsive CSS
├── app.js          # Vanilla JavaScript
├── robots.txt      # SEO koruma
└── README.md       # Bu dosya
```

## Default PIN

**PIN: 1234**

PIN'i değiştirmek için: `Controllers/AuthController.cs` dosyasındaki `CATALOG_PIN` sabitini düzenleyin.

## Kullanım

1. Backend'i çalıştırın:
   ```bash
   cd B2BApi
   dotnet run
   ```

2. Tarayıcıda açın:
   ```
   http://localhost:5042
   ```

3. **Detayları görmek için**:
   - "🔓 Detayları Göster" butonuna tıklayın
   - PIN: 1234 girin
   - 1 saat süreyle tüm detayları göreceksiniz

## Raspberry Pi Zero 2W'ye Deploy

1. .NET 8 SDK yükleyin
2. Projeyi kopyalayın
3. `dotnet publish -c Release -r linux-arm` ile derleyin
4. Çıktıyı RPi'ye kopyalayın
5. Çalıştırın

## Session Süresi

Session 1 saat boyunca aktif kalır. Değiştirmek için:
`Controllers/AuthController.cs` → `SESSION_DURATION_HOURS`

## Güvenlik Notları

- PIN'i mutlaka değiştirin
- HTTPS kullanın (production'da)
- robots.txt korumalı ancak lokal ağda kullanımı öneririz
