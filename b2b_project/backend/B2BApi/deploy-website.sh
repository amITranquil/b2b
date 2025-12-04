#!/bin/bash
# Website dosyalarını production server'a deploy etme scripti

echo "🚀 B2B Website Deployment Script"
echo "=================================="

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Değişkenler
SOURCE_DIR="./wwwroot"
TARGET_SERVER="dietpi@192.168.1.8"
TARGET_DIR="/var/www/hvk"

# Local'de kaynak klasörü kontrol et
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Hata: $SOURCE_DIR klasörü bulunamadı!${NC}"
    exit 1
fi

echo -e "${YELLOW}📂 Kaynak dizin: $SOURCE_DIR${NC}"
echo -e "${YELLOW}🎯 Hedef: $TARGET_SERVER:$TARGET_DIR${NC}"
echo ""

# Dosyaları listele
echo -e "${GREEN}📋 Deploy edilecek dosyalar:${NC}"
ls -lh $SOURCE_DIR/

echo ""
read -p "Devam etmek istiyor musunuz? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "İptal edildi."
    exit 0
fi

# SSH ile hedef dizini oluştur
echo -e "${YELLOW}📁 Hedef dizin oluşturuluyor...${NC}"
ssh $TARGET_SERVER "mkdir -p $TARGET_DIR"

# rsync ile dosyaları kopyala
echo -e "${YELLOW}📤 Dosyalar kopyalanıyor...${NC}"
rsync -avz --progress \
    --exclude='.DS_Store' \
    --exclude='*.md' \
    --exclude='*.sh' \
    $SOURCE_DIR/ $TARGET_SERVER:$TARGET_DIR/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Website başarıyla deploy edildi!${NC}"
    echo ""
    echo -e "${GREEN}🌐 Erişim URL'leri:${NC}"
    echo -e "   Website: https://urlateknik.com/hvk/"
    echo -e "   API: https://urlateknik.com/hvk/api/"
    echo ""
    echo -e "${YELLOW}⚠️  Kontrol listesi:${NC}"
    echo "   1. nginx yapılandırması doğru mu?"
    echo "   2. SSL sertifikası var mı?"
    echo "   3. config.js production URL'i doğru mu?"
    echo "   4. API servisi çalışıyor mu?"
else
    echo -e "${RED}❌ Deploy başarısız!${NC}"
    exit 1
fi
