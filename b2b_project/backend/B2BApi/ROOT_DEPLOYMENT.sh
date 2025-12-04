#!/bin/bash
# ROOT KULLANICISI İLE DEPLOYMENT
# Terminal'den root@192.168.1.8'e login olduktan sonra bu komutları çalıştırın

echo "==================================================================="
echo "🚀 B2B DEPLOYMENT - ROOT KULLANICISI"
echo "==================================================================="
echo ""
echo "Şifre: TRansit2022,."
echo ""

# =================================================================
# ADIM 1: Klasörleri oluştur (root@192.168.1.8 terminalinde)
# =================================================================
echo "📁 ADIM 1/10 - Klasörler oluşturuluyor..."

mkdir -p /home/dietpi/b2bapi/publish
mkdir -p /var/www/hvk
chown -R dietpi:dietpi /home/dietpi/b2bapi
echo "✅ Klasörler hazır"

# =================================================================
# ADIM 2: YENİ TERMINAL AÇ - Local'den API dosyalarını kopyala
# =================================================================
echo ""
echo "📤 ADIM 2/10 - API kopyalama komutu:"
echo ""
echo "Yeni bir TERMINAL açıp şu komutu çalıştırın:"
echo "--------------------------------------------------------------"
cat << 'LOCALCMD'
cd "/Users/sakinburakcivelek/flutter_and_c#/b2b/b2b_project/backend/B2BApi"

rsync -avz --progress \
    --exclude='*.db' \
    --exclude='*.db-shm' \
    --exclude='*.db-wal' \
    --exclude='wwwroot/*.html' \
    --exclude='wwwroot/*.js' \
    --exclude='wwwroot/*.css' \
    --exclude='wwwroot/*.md' \
    ./bin/Release/publish/ root@192.168.1.8:/home/dietpi/b2bapi/publish/
LOCALCMD
echo "--------------------------------------------------------------"
echo ""
read -p "API kopyalandı mı? (y) " -n 1 -r
echo ""

# =================================================================
# ADIM 3: Local'den Website dosyalarını kopyala
# =================================================================
echo ""
echo "📤 ADIM 3/10 - Website kopyalama komutu:"
echo ""
echo "Aynı local terminal'de şunu çalıştırın:"
echo "--------------------------------------------------------------"
cat << 'LOCALCMD2'
rsync -avz --progress \
    --exclude='.DS_Store' \
    --exclude='*.md' \
    --exclude='*.sh' \
    ./wwwroot/ root@192.168.1.8:/var/www/hvk/
LOCALCMD2
echo "--------------------------------------------------------------"
echo ""
read -p "Website kopyalandı mı? (y) " -n 1 -r
echo ""

# =================================================================
# ADIM 4: appsettings.Production.json
# =================================================================
echo ""
echo "⚙️  ADIM 4/10 - Production ayarları oluşturuluyor..."

cat > /home/dietpi/b2bapi/publish/appsettings.Production.json << 'EOF'
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
EOF

echo "✅ appsettings.Production.json oluşturuldu"

# =================================================================
# ADIM 5: Dosya izinlerini ayarla
# =================================================================
echo ""
echo "🔐 ADIM 5/10 - İzinler ayarlanıyor..."

chown -R dietpi:dietpi /home/dietpi/b2bapi/publish
chmod -R 755 /home/dietpi/b2bapi/publish
echo "✅ İzinler ayarlandı"

# =================================================================
# ADIM 6: Systemd service
# =================================================================
echo ""
echo "🔧 ADIM 6/10 - Systemd service oluşturuluyor..."

tee /etc/systemd/system/b2b-api.service > /dev/null << 'EOF'
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
EOF

echo "✅ Service dosyası oluşturuldu"

# =================================================================
# ADIM 7: Service'i başlat
# =================================================================
echo ""
echo "🚀 ADIM 7/10 - Service başlatılıyor..."

systemctl daemon-reload
systemctl enable b2b-api.service
systemctl restart b2b-api.service

sleep 3

systemctl status b2b-api.service --no-pager -l

# =================================================================
# ADIM 8: lighttpd proxy modülü
# =================================================================
echo ""
echo "🔌 ADIM 8/10 - lighttpd proxy modülü kontrol ediliyor..."

if ! lighttpd -v | grep -q "mod_proxy"; then
    echo "⚠️  mod_proxy bulunamadı, aktifleştiriliyor..."
    lighty-enable-mod proxy
fi

echo "✅ Proxy modülü hazır"

# =================================================================
# ADIM 9: lighttpd konfigürasyonu
# =================================================================
echo ""
echo "🔧 ADIM 9/10 - lighttpd konfigürasyonu oluşturuluyor..."

tee /etc/lighttpd/conf-available/99-hvk.conf > /dev/null << 'EOF'
server.modules += ( "mod_proxy" )

$HTTP["url"] =~ "^/hvk/" {
    alias.url = ( "/hvk/" => "/var/www/hvk/" )

    $HTTP["url"] !~ "^/hvk/api/" {
        index-file.names = ( "index.html" )

        url.rewrite-if-not-file = (
            "^/hvk/(.*)$" => "/hvk/index.html"
        )
    }
}

$HTTP["url"] =~ "^/hvk/api/" {
    proxy.balance = "round-robin"
    proxy.server = (
        "" => (
            (
                "host" => "127.0.0.1",
                "port" => 5000
            )
        )
    )
}
EOF

# Konfigürasyonu aktifleştir
ln -sf /etc/lighttpd/conf-available/99-hvk.conf /etc/lighttpd/conf-enabled/

echo "✅ lighttpd konfigürasyonu oluşturuldu"

# =================================================================
# ADIM 10: lighttpd'yi yeniden başlat
# =================================================================
echo ""
echo "🔄 ADIM 10/10 - lighttpd yeniden başlatılıyor..."

systemctl restart lighttpd
systemctl status lighttpd --no-pager -l

# =================================================================
# Test
# =================================================================
echo ""
echo "==================================================================="
echo "🧪 TESTLER"
echo "==================================================================="
echo ""

echo "API Test:"
curl -I http://localhost:5000/api/products 2>&1 | head -5

echo ""
echo "Website Test:"
curl -I http://192.168.1.8/hvk/ 2>&1 | head -5

echo ""
echo "==================================================================="
echo "✅ DEPLOYMENT TAMAMLANDI!"
echo "==================================================================="
echo ""
echo "📍 Erişim URL'leri:"
echo "   Website: http://192.168.1.8/hvk/"
echo "   API: http://192.168.1.8/hvk/api/"
echo ""
echo "📋 Yararlı komutlar:"
echo "   systemctl status b2b-api.service"
echo "   journalctl -u b2b-api.service -f"
echo "   systemctl status lighttpd"
echo "   tail -f /var/log/lighttpd/error.log"
echo ""
echo "==================================================================="
