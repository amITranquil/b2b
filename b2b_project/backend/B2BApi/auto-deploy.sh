#!/usr/bin/expect -f

set timeout -1
set password "TRansit2022,."
set host "dietpi@192.168.1.8"

# 1. Klasörleri oluştur
spawn ssh $host "mkdir -p /home/dietpi/b2bapi/publish /var/www/hvk && sudo mkdir -p /var/www/hvk && sudo chown dietpi:dietpi /var/www/hvk"
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n✅ Klasörler oluşturuldu\n"

# 2. API dosyalarını kopyala
puts "📤 API dosyaları kopyalanıyor...\n"
spawn rsync -avz --progress --exclude=*.db --exclude=wwwroot ./bin/Release/publish/ $host:/home/dietpi/b2bapi/publish/
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n✅ API deploy edildi\n"

# 3. Website dosyalarını kopyala
puts "📤 Website dosyaları kopyalanıyor...\n"
spawn rsync -avz --progress --exclude=.DS_Store --exclude=*.md --exclude=*.sh ./wwwroot/ $host:/var/www/hvk/
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n✅ Website deploy edildi\n"

# 4. appsettings.Production.json oluştur
puts "⚙️  appsettings.Production.json oluşturuluyor...\n"
spawn ssh $host "cat > /home/dietpi/b2bapi/publish/appsettings.Production.json << 'EOF'
{
  \"Logging\": {
    \"LogLevel\": {
      \"Default\": \"Information\",
      \"Microsoft.AspNetCore\": \"Warning\",
      \"Microsoft.EntityFrameworkCore\": \"Warning\"
    }
  },
  \"ConnectionStrings\": {
    \"DefaultConnection\": \"Data Source=/home/dietpi/b2bapi/b2b_products.db\"
  },
  \"AllowedHosts\": \"*\",
  \"Kestrel\": {
    \"Endpoints\": {
      \"Http\": {
        \"Url\": \"http://localhost:5000\"
      }
    }
  }
}
EOF"
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n✅ Production ayarları oluşturuldu\n"

# 5. Systemd service oluştur
puts "🔧 Systemd service oluşturuluyor...\n"
spawn ssh $host "echo 'TRansit2022,.' | sudo -S tee /etc/systemd/system/b2b-api.service > /dev/null << 'EOF'
\[Unit\]
Description=B2B API Service
After=network.target

\[Service\]
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

\[Install\]
WantedBy=multi-user.target
EOF"
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n✅ Service oluşturuldu\n"

# 6. Service'i başlat
puts "🚀 Service başlatılıyor...\n"
spawn ssh $host "echo 'TRansit2022,.' | sudo -S systemctl daemon-reload && sudo systemctl enable b2b-api.service && sudo systemctl restart b2b-api.service"
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

sleep 2

puts "\n✅ Service başlatıldı\n"

# 7. lighttpd konfigürasyonunu kopyala
puts "🔧 lighttpd konfigürasyonu oluşturuluyor...\n"
spawn scp ./lighttpd-hvk.conf $host:/tmp/99-hvk.conf
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

spawn ssh $host "echo 'TRansit2022,.' | sudo -S mv /tmp/99-hvk.conf /etc/lighttpd/conf-available/ && sudo -S lighttpd-enable-mod hvk && sudo -S systemctl restart lighttpd"
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n✅ lighttpd yapılandırıldı\n"

# 8. Test
puts "🧪 Testler yapılıyor...\n"
spawn ssh $host "curl -I http://localhost:5000/api/products && curl -I http://192.168.1.8/hvk/"
expect {
    "password:" { send "$password\r"; exp_continue }
    eof
}

puts "\n\n🎉 Deployment tamamlandı!\n"
puts "📍 Erişim URL'leri:\n"
puts "   Website: http://192.168.1.8/hvk/\n"
puts "   API: http://192.168.1.8/hvk/api/\n"
