#!/bin/bash
# API'yi production server'a deploy etme scripti

echo "🚀 B2B API Deployment Script"
echo "============================"

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Değişkenler
PROJECT_DIR="."
TARGET_SERVER="dietpi@192.168.1.8"
TARGET_DIR="/home/dietpi/b2bapi"
PUBLISH_DIR="$TARGET_DIR/publish"
SERVICE_NAME="b2b-api.service"

echo -e "${YELLOW}🔨 API Build başlatılıyor...${NC}"

# Release build
dotnet publish -c Release -o ./bin/Release/publish

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build başarısız!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build tamamlandı${NC}"
echo ""

# Dosya boyutlarını göster
echo -e "${GREEN}📦 Paket boyutu:${NC}"
du -sh ./bin/Release/publish

echo ""
read -p "Server'a deploy edilsin mi? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "İptal edildi."
    exit 0
fi

# SSH ile hedef dizini oluştur
echo -e "${YELLOW}📁 Hedef dizinler oluşturuluyor...${NC}"
ssh $TARGET_SERVER "mkdir -p $PUBLISH_DIR"

# API'yi durdur
echo -e "${YELLOW}🛑 API servisi durduruluyor...${NC}"
ssh $TARGET_SERVER "sudo systemctl stop $SERVICE_NAME" 2>/dev/null || true

# Dosyaları kopyala
echo -e "${YELLOW}📤 Dosyalar kopyalanıyor...${NC}"
rsync -avz --progress \
    --exclude='*.db' \
    --exclude='*.db-shm' \
    --exclude='*.db-wal' \
    --exclude='wwwroot' \
    --exclude='images' \
    ./bin/Release/publish/ $TARGET_SERVER:$PUBLISH_DIR/

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Dosya kopyalama başarısız!${NC}"
    exit 1
fi

# appsettings.Production.json'ı kontrol et
echo -e "${YELLOW}⚙️  Production ayarları kontrol ediliyor...${NC}"
ssh $TARGET_SERVER "ls -la $PUBLISH_DIR/appsettings.Production.json" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}⚠️  appsettings.Production.json bulunamadı!${NC}"
fi

# API'yi başlat
echo -e "${YELLOW}🚀 API servisi başlatılıyor...${NC}"
ssh $TARGET_SERVER "sudo systemctl start $SERVICE_NAME"

sleep 2

# Servis durumunu kontrol et
echo -e "${YELLOW}📊 Servis durumu:${NC}"
ssh $TARGET_SERVER "sudo systemctl status $SERVICE_NAME --no-pager -l" | head -20

# API'ye test isteği gönder
echo ""
echo -e "${YELLOW}🧪 API test ediliyor...${NC}"
sleep 3
ssh $TARGET_SERVER "curl -s http://localhost:5000/api/products -I | head -5"

echo ""
echo -e "${GREEN}✅ API deploy tamamlandı!${NC}"
echo ""
echo -e "${GREEN}📋 Sonraki adımlar:${NC}"
echo "   1. API loglarını kontrol et: sudo journalctl -u $SERVICE_NAME -f"
echo "   2. Test et: curl http://localhost:5000/api/products"
echo "   3. Website'i deploy et: ./deploy-website.sh"
