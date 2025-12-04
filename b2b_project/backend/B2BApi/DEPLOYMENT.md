# B2B API ve Website Deployment Talimatları

## Raspberry Pi'ye Production Deployment

### 1. Proje Yapısı

```
Production Dosya Yapısı (DietPi):
/home/dietpi/
  └── b2bapi/
      ├── publish/              # .NET Core API (compiled)
      │   ├── B2BApi.dll
      │   ├── appsettings.json
      │   ├── appsettings.Production.json
      │   └── ...
      └── b2b_products.db       # SQLite database

/var/www/
  └── hvk/                      # Website dosyaları (nginx serve eder)
      ├── index.html
      ├── config.js             # ÖNEMLİ: API URL'ini burada ayarlayın
      ├── app.js
      ├── styles.css
      └── images/
```

### 2. Website Deployment (Farklı Dizin/Subdomain)

#### Seçenek A: Nginx ile Alt Dizinde (ÖNERİLEN - URLA TEKNİK SETUP)

Website URL: `https://urlateknik.com/hvk/`
API URL: `https://urlateknik.com/hvk/api/` (nginx reverse proxy ile)

**Nginx Configuration** (`/etc/nginx/sites-available/urlateknik`):

```nginx
server {
    listen 80;
    listen 443 ssl;
    server_name urlateknik.com www.urlateknik.com;

    # SSL Sertifikaları (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/urlateknik.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/urlateknik.com/privkey.pem;

    # Website - /hvk/ altında
    location /hvk/ {
        alias /var/www/urlateknik/hvk/;
        index index.html;
        try_files $uri $uri/ =404;
    }

    # API Reverse Proxy - /hvk/api/ altında
    location /hvk/api/ {
        proxy_pass http://localhost:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # CORS headers (eğer API'de ayarlanmadıysa)
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
    }

    # Resim dosyaları için özel cache
    location /hvk/images/ {
        alias /var/www/urlateknik/hvk/images/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

**config.js ayarı:**
```javascript
production: {
    // Nginx reverse proxy kullanıldığı için aynı domain
    apiUrl: 'https://urlateknik.com'
    // API endpoint: https://urlateknik.com/hvk/api/
}
```

#### Seçenek B: Apache ile Alt Dizinde

**Apache Configuration** (`/etc/apache2/sites-available/000-default.conf`):

```apache
<VirtualHost *:80>
    ServerName yourpi.local
    DocumentRoot /var/www/html

    Alias /b2b /home/pi/www/b2b
    <Directory /home/pi/www/b2b>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # API Proxy (opsiyonel)
    ProxyPreserveHost On
    ProxyPass /api http://localhost:5000/api
    ProxyPassReverse /api http://localhost:5000/api
</VirtualHost>
```

#### Seçenek B: Farklı Port (Test için)

Website URL: `http://yourpi.local:8080/`
API URL: `http://yourpi.local:5000/api/`

Basit bir HTTP server kullanın:
```bash
cd /var/www/urlateknik/hvk
python3 -m http.server 8080
```

### 3. Hızlı Deployment (Otomatik Scriptler)

#### A. API Deployment

```bash
# Local'de (Mac/PC):
cd backend/B2BApi
./deploy-api.sh
```

Bu script:
- ✅ Release build yapar
- ✅ Dosyaları `/home/dietpi/b2bapi/publish/` dizinine kopyalar
- ✅ API servisini yeniden başlatır
- ✅ Test eder

#### B. Website Deployment

```bash
# Local'de (Mac/PC):
cd backend/B2BApi
./deploy-website.sh
```

Bu script:
- ✅ wwwroot dosyalarını `/var/www/hvk/` dizinine kopyalar
- ✅ Dosya izinlerini ayarlar
- ✅ nginx restart gerekmez (static files)

### 4. Manuel .NET API Deployment

#### A. Dosyaları Kopyalama (Manuel Yöntem)

```bash
# 1. Local'de build yap
dotnet publish -c Release -o ./bin/Release/publish

# 2. Server'a kopyala
scp -r ./bin/Release/publish/* dietpi@urlateknik.com:/home/dietpi/b2bapi/publish/

# 3. Server'da servisi yeniden başlat
ssh dietpi@urlateknik.com "sudo systemctl restart b2b-api.service"
```

#### B. .NET SDK Kurulumu (RPi'de)

```bash
# .NET 8.0 SDK kurulumu
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0

# PATH'e ekleme
echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/.dotnet' >> ~/.bashrc
source ~/.bashrc
```

#### C. Gerekli Paketleri Yükleme

```bash
cd /home/pi/b2b-api/B2BApi
dotnet restore
dotnet build -c Release
```

#### D. Production Environment Ayarı

**appsettings.Production.json** oluşturun (`/home/dietpi/b2bapi/publish/` içinde):

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=/home/dietpi/b2bapi/b2b_products.db"
  },
  "AllowedHosts": "*",
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://localhost:5000"
      }
    }
  }
}
```

**NOT:** Bu dosyayı manuel oluşturmanız gerekebilir, deploy scripti mevcut dosyaları korur.

#### E. Systemd Service (Otomatik Başlatma)

**`/etc/systemd/system/b2b-api.service`** oluşturun:

```ini
[Unit]
Description=B2B API Service
After=network.target

[Service]
Type=notify
User=dietpi
WorkingDirectory=/home/dietpi/b2bapi/publish
ExecStart=/usr/bin/dotnet B2BApi.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=b2b-api
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000

[Install]
WantedBy=multi-user.target
```

**NOT:**
- `dotnet run` yerine `dotnet B2BApi.dll` kullanılıyor (production için daha hızlı)
- DietPi'de .NET genelde `/usr/bin/dotnet` konumunda
- Database `/home/dietpi/b2bapi/b2b_products.db` olmalı

**Service'i başlatma:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable b2b-api.service
sudo systemctl start b2b-api.service
sudo systemctl status b2b-api.service

# Logları izleme
sudo journalctl -u b2b-api.service -f
```

### 4. Website Konfigürasyonu

**wwwroot/config.js** dosyasını düzenleyin:

```javascript
const config = {
    development: {
        apiUrl: 'http://localhost:5000'
    },
    production: {
        // Nginx reverse proxy kullanıldığı için
        apiUrl: 'https://urlateknik.com'
        // API endpoint: https://urlateknik.com/hvk/api/

        // Eğer doğrudan port kullanılacaksa:
        // apiUrl: 'http://192.168.1.100:5000'
    }
};
```

### 5. Güvenlik ve Optimizasyon

#### A. HTTPS Kurulumu (Let's Encrypt)

```bash
# Certbot kurulumu
sudo apt-get install certbot python3-certbot-nginx

# SSL sertifikası alma
sudo certbot --nginx -d yourdomain.com

# Otomatik yenileme
sudo certbot renew --dry-run
```

#### B. Firewall Ayarları

```bash
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5000/tcp  # API (opsiyonel - nginx proxy kullanıyorsanız kapatın)
sudo ufw enable
```

#### C. Database Backup

```bash
# Cron job ekleyin (/etc/crontab)
0 2 * * * pi cp /home/pi/b2b-api/b2b_products.db /home/pi/backups/b2b_products_$(date +\%Y\%m\%d).db
```

### 6. Güncelleme (Update) Prosedürü

```bash
# API Güncelleme
cd /home/pi/b2b-api
git pull
cd B2BApi
dotnet build -c Release
sudo systemctl restart b2b-api.service

# Website Güncelleme
cd /home/pi/www/b2b
# Dosyaları yeni versiyonlarla değiştirin
# Nginx/Apache restart gerekmez (static files)
```

### 7. Troubleshooting

#### API çalışmıyor:
```bash
# Service durumunu kontrol et
sudo systemctl status b2b-api.service

# Logları incele
sudo journalctl -u b2b-api.service -n 100

# Port dinleniyor mu?
sudo netstat -tulpn | grep 5000
```

#### Website API'ye bağlanamıyor:
```bash
# config.js'deki API URL'ini kontrol et
# CORS ayarlarını kontrol et (Program.cs)
# Firewall'u kontrol et
sudo ufw status

# API'ye curl ile test
curl http://localhost:5000/api/products
```

#### Database hataları:
```bash
# Database dosya izinlerini kontrol et
ls -la /home/pi/b2b-api/b2b_products.db

# İzin ver
chmod 644 /home/pi/b2b-api/b2b_products.db
chown pi:pi /home/pi/b2b-api/b2b_products.db
```

### 8. Önerilen Mimari (Production)

```
                    Internet
                       |
                   [Nginx:80/443]
                    /         \
                   /           \
          [Website:80]    [Reverse Proxy]
          /b2b/                  |
       (Static Files)      [API:5000]
                                 |
                          [SQLite DB]
```

### 9. Test Checklist

- [ ] Website localhost dışında açılıyor mu? (Environment detection çalışıyor mu?)
- [ ] config.js production API URL'i doğru mu?
- [ ] API çalışıyor mu? (systemctl status)
- [ ] CORS ayarları doğru mu?
- [ ] Dark mode çalışıyor mu?
- [ ] PIN authentication çalışıyor mu?
- [ ] Ürün resimleri yükleniyor mu?
- [ ] Scraping çalışıyor mu?
- [ ] Database yazma/okuma çalışıyor mu?
- [ ] Service otomatik başlıyor mu? (reboot sonrası)

## Hızlı Setup (RPi'de İlk Kurulum)

```bash
# 1. .NET SDK kur
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0
echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/.dotnet' >> ~/.bashrc
source ~/.bashrc

# 2. Proje dizinleri oluştur
mkdir -p ~/b2b-api ~/www/b2b

# 3. Nginx kur
sudo apt-get update
sudo apt-get install nginx

# 4. Systemd service oluştur (yukarıdaki template'i kullan)
sudo nano /etc/systemd/system/b2b-api.service

# 5. Website dosyalarını kopyala
# (Local'den SCP ile veya manuel olarak)

# 6. config.js'i düzenle
nano ~/www/b2b/config.js

# 7. Nginx'i yapılandır
sudo nano /etc/nginx/sites-available/default

# 8. Servisleri başlat
sudo systemctl daemon-reload
sudo systemctl enable b2b-api.service
sudo systemctl start b2b-api.service
sudo systemctl restart nginx

# 9. Test et
curl http://localhost:5000/api/products
```

## Son Notlar

1. **API ve Website Ayrımı**: Website static files olarak serve edilir, API ayrı bir process olarak çalışır
2. **Environment Detection**: config.js otomatik olarak localhost'ta development, başka yerlerde production kullanır
3. **CORS**: Production'da AllowAnyOrigin kullanılıyor, daha güvenli için belirli domain'leri belirtin
4. **Dark Mode**: LocalStorage ile kaydediliyor, kullanıcı tercihini hatırlıyor
5. **Güvenlik**: Production'da mutlaka HTTPS kullanın (Let's Encrypt ücretsiz)
