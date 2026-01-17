#!/bin/bash
# USB KAMERA MODÜLÜ - HIZLI BAŞLANGIÇ

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          USB Kamera Modülü - Hızlı Test Rehberi              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")" || exit

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. HAZIRLIK${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "   a) Test dosyalarının çalıştırılabilir olmasını sağla:"
echo "      ${YELLOW}chmod +x code/r_tests/test_usb_*.sh${NC}"
echo ""
echo "   b) FFmpeg'i kur (gerekirse):"
echo "      ${YELLOW}sudo apt-get install ffmpeg${NC}"
echo ""

echo -e "${BLUE}2. TESTLERİ ÇALIŞTIR${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "   ${YELLOW}Seçenek A: Tüm testleri interaktif mode'da${NC}"
echo "      ${GREEN}./code/r_tests/run_all_usb_tests.sh${NC}"
echo ""
echo "   ${YELLOW}Seçenek B: Hızlı test (Advanced)${NC}"
echo "      ${GREEN}./code/r_tests/test_usb_advanced.sh${NC}"
echo ""
echo "   ${YELLOW}Seçenek C: Entegrasyon testi${NC}"
echo "      ${GREEN}./code/r_tests/test_usb_integration.sh${NC}"
echo ""
echo "   ${YELLOW}Seçenek D: Device testi${NC}"
echo "      ${GREEN}./code/r_tests/test_usb_real_device.sh${NC}"
echo ""

echo -e "${BLUE}3. ÇIKTIYI YORUMLA${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "   ${GREEN}✓${NC} = Test geçti"
echo "   ${YELLOW}⚠${NC} = Uyarı (kontrol et)"
echo "   ✗ = Test başarısız (düzelt gerekli)"
echo ""

echo -e "${BLUE}4. SONUÇLAR${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "   Tüm testler geçtiğinde:"
echo "      1. make clean && make vehicle ile derle"
echo "      2. USB kamerayı bağla"
echo "      3. Uygulamayı çalıştır"
echo ""

echo -e "${BLUE}5. SORUN GİDERME${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "   Problem: FFmpeg not found"
echo "      Çözüm: ${YELLOW}sudo apt-get install ffmpeg${NC}"
echo ""
echo "   Problem: Permission denied"
echo "      Çözüm: ${YELLOW}chmod +x code/r_tests/test_usb_*.sh${NC}"
echo ""
echo "   Problem: Bazı testler başarısız"
echo "      Çözüm: Dokumentasyon oku: USB_TEST_DOCUMENTATION_TR.md"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
