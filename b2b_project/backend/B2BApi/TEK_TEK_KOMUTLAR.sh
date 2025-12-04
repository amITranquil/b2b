#!/bin/bash
# Her satırı tek tek kopyala-yapıştır yapın

# =================================================================
# ADIM 1: Klasörleri oluştur (Server'da çalıştır)
# =================================================================
mkdir -p /home/dietpi/b2bapi/publish
sudo mkdir -p /var/www/hvk
sudo chown dietpi:dietpi /var/www/hvk
echo "✅ Klasörler oluşturuldu"

# =================================================================
# ADIM 2: Local'e dön ve API dosyalarını kopyala
# =================================================================
# YENİ TERMINAL aç ve şunu çalıştır:

cd "/Users/sakinburakcivelek/flutter_and_c#/b2b/b2b_project/backend/B2BApi"

rsync -avz --progress --exclude='*.db' --exclude='*.db-shm' --exclude='*.db-wal' --exclude='wwwroot/*.html' --exclude='wwwroot/*.js' --exclude='wwwroot/*.css' --exclude='wwwroot/*.md' ./bin/Release/publish/ dietpi@192.168.1.8:/home/dietpi/b2bapi/publish/

# =================================================================
# ADIM 3: Website dosyalarını kopyala (Aynı local terminal)
# =================================================================
rsync -avz --progress --exclude='.DS_Store' --exclude='*.md' --exclude='*.sh' ./wwwroot/ dietpi@192.168.1.8:/var/www/hvk/

# =================================================================
# ADIM 4: Server terminaline dön - appsettings.Production.json
# =================================================================
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
# ADIM 5: Systemd service oluştur
# =================================================================
sudo tee /etc/systemd/system/b2b-api.service > /dev/null << 'EOF'
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
# ADIM 6: Service'i etkinleştir ve başlat
# =================================================================
sudo systemctl daemon-reload
sudo systemctl enable b2b-api.service
sudo systemctl start b2b-api.service
sudo systemctl status b2b-api.service

# =================================================================
# ADIM 7: lighttpd proxy modülünü aktifleştir
# =================================================================
sudo lighty-enable-mod proxy
echo "✅ Proxy modülü aktifleştirildi"

# =================================================================
# ADIM 8: lighttpd konfigürasyonu oluştur
# =================================================================
sudo tee /etc/lighttpd/conf-available/99-hvk.conf > /dev/null << 'EOF'
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

echo "✅ lighttpd konfigürasyonu oluşturuldu"

# =================================================================
# ADIM 9: lighttpd konfigürasyonunu aktifleştir
# =================================================================
sudo ln -sf /etc/lighttpd/conf-available/99-hvk.conf /etc/lighttpd/conf-enabled/
sudo systemctl restart lighttpd
sudo systemctl status lighttpd

# =================================================================
# ADIM 10: Test
# =================================================================
echo ""
echo "🧪 Testler yapılıyor..."
curl -I http://localhost:5000/api/products
echo ""
curl -I http://192.168.1.8/hvk/

echo ""
echo "🎉 Deployment tamamlandı!"
echo "📍 Website: http://192.168.1.8/hvk/"
echo "📍 API: http://192.168.1.8/hvk/api/"
