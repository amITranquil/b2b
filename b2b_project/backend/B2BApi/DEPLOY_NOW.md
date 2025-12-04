# 🚀 Hızlı Deployment - Şimdi Çalıştır

## ✅ Build Tamamlandı!

API başarıyla build edildi: `./bin/Release/publish/`

## 📦 Manuel Deployment Komutları

Aşağıdaki komutları **YENİ BİR TERMINAL** penceresinde sırayla çalıştırın:

### 1. Server'da Klasörleri Oluştur

```bash
ssh dietpi@192.168.1.8 "mkdir -p /home/dietpi/b2bapi/publish /var/www/hvk"
```

### 2. API'yi Deploy Et

```bash
cd /Users/sakinburakcivelek/flutter_and_c#/b2b/b2b_project/backend/B2BApi

rsync -avz --progress \
    --exclude='*.db' \
    --exclude='*.db-shm' \
    --exclude='*.db-wal' \
    --exclude='wwwroot' \
    ./bin/Release/publish/ dietpi@192.168.1.8:/home/dietpi/b2bapi/publish/
```

### 3. Website'i Deploy Et

```bash
rsync -avz --progress \
    --exclude='.DS_Store' \
    --exclude='*.md' \
    --exclude='*.sh' \
    ./wwwroot/ dietpi@192.168.1.8:/var/www/hvk/
```

### 4. Production Ayarlarını Oluştur

Server'da appsettings.Production.json oluşturun:

```bash
ssh dietpi@192.168.1.8

# Server'da:
nano /home/dietpi/b2bapi/publish/appsettings.Production.json
```

İçeriği:

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

### 5. Systemd Service Oluştur

```bash
sudo nano /etc/systemd/system/b2b-api.service
```

İçeriği:

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

### 6. Service'i Başlat

```bash
sudo systemctl daemon-reload
sudo systemctl enable b2b-api.service
sudo systemctl start b2b-api.service
sudo systemctl status b2b-api.service
```

### 7. nginx Yapılandır

```bash
sudo nano /etc/nginx/sites-available/urlateknik
```

İçeriği:

```nginx
server {
    listen 80;
    server_name urlateknik.com www.urlateknik.com 192.168.1.8;

    # Website - /hvk/ altında
    location /hvk/ {
        alias /var/www/hvk/;
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
    }

    # Resim dosyaları
    location /hvk/images/ {
        alias /var/www/hvk/images/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

Aktifleştir:

```bash
sudo ln -sf /etc/nginx/sites-available/urlateknik /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 8. Test Et

```bash
# API testi
curl http://localhost:5000/api/products -I

# Website testi
curl http://192.168.1.8/hvk/ -I
```

## 🌐 Erişim URL'leri

- Website: http://192.168.1.8/hvk/
- API: http://192.168.1.8/hvk/api/products

## 📋 Sorun Giderme

API çalışmıyor mu?

```bash
# Logları kontrol et
sudo journalctl -u b2b-api.service -f

# Service durumunu kontrol et
sudo systemctl status b2b-api.service

# Port dinleniyor mu?
sudo netstat -tulpn | grep 5000
```

nginx çalışmıyor mu?

```bash
# nginx logları
sudo tail -f /var/log/nginx/error.log

# nginx test
sudo nginx -t

# nginx restart
sudo systemctl restart nginx
```
