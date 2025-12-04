#!/bin/bash
# Hızlı Deployment Script
# Şifreyi her komut için soracak

SERVER="root@192.168.1.8"

echo "🚀 B2B Deployment Başlıyor..."
echo "=================================="
echo ""

# 1. Klasörleri oluştur
echo "📁 1/7 - Klasörler oluşturuluyor..."
ssh $SERVER "mkdir -p /home/dietpi/b2bapi/publish && mkdir -p /var/www/hvk && chown dietpi:dietpi /home/dietpi/b2bapi/publish"

# 2. API deploy (wwwroot/images dahil!)
echo ""
echo "📤 2/7 - API dosyaları kopyalanıyor (resimler dahil)..."
rsync -avz --progress \
    --exclude='*.db' \
    --exclude='*.db-shm' \
    --exclude='*.db-wal' \
    --exclude='wwwroot/*.html' \
    --exclude='wwwroot/*.js' \
    --exclude='wwwroot/*.css' \
    --exclude='wwwroot/*.md' \
    ./bin/Release/publish/ $SERVER:/home/dietpi/b2bapi/publish/

# 3. Website deploy
echo ""
echo "📤 3/7 - Website dosyaları kopyalanıyor..."
rsync -avz --progress \
    --exclude='.DS_Store' \
    --exclude='*.md' \
    --exclude='*.sh' \
    ./wwwroot/ $SERVER:/var/www/hvk/

# 4. appsettings.Production.json
echo ""
echo "⚙️  4/7 - Production ayarları oluşturuluyor..."
ssh $SERVER 'cat > /home/dietpi/b2bapi/publish/appsettings.Production.json << "EOF"
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
EOF'

# 5. Systemd service
echo ""
echo "🔧 5/7 - Systemd service oluşturuluyor..."
ssh $SERVER 'sudo tee /etc/systemd/system/b2b-api.service > /dev/null << "EOF"
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
EOF'

# 6. Service başlat
echo ""
echo "🚀 6/7 - Service başlatılıyor..."
ssh $SERVER "systemctl daemon-reload && systemctl enable b2b-api.service && systemctl restart b2b-api.service"

sleep 2

# 7. lighttpd konfigüre et
echo ""
echo "🔧 7/7 - lighttpd yapılandırılıyor..."
scp ./lighttpd-hvk.conf $SERVER:/tmp/99-hvk.conf
ssh $SERVER "mv /tmp/99-hvk.conf /etc/lighttpd/conf-available/ && lighty-enable-mod proxy && systemctl restart lighttpd"

echo ""
echo "✅ Deployment tamamlandı!"
echo ""
echo "🧪 Test ediliyor..."
ssh $SERVER "curl -I http://localhost:5000/api/products 2>&1 | head -5"

echo ""
echo "🎉 Başarılı!"
echo "📍 Erişim URL'leri:"
echo "   Website: http://192.168.1.8/hvk/"
echo "   API: http://192.168.1.8/hvk/api/"
echo ""
echo "📋 Kontrol komutları:"
echo "   sudo systemctl status b2b-api.service"
echo "   sudo journalctl -u b2b-api.service -f"
