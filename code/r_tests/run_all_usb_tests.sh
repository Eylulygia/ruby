#!/bin/bash
# USB Camera Module - Comprehensive Test Suite Runner
# Runs all 3 test suites in sequence
# Run: chmod +x run_all_tests.sh && ./run_all_tests.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

clear

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  USB CAMERA MODULE - KAPSAMLI TEST PAKETI             ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Bu script 3 kapsamlı test suite çalıştıracak:"
echo ""
echo -e "${MAGENTA}1. ADVANCED TESTS${NC}       - Unit tests + static analysis"
echo "   - Kod analizi (null pointers, buffers)"
echo "   - Thread safety kontrolleri"
echo "   - State machine validasyonu"
echo "   - Ring buffer analizi"
echo "   - Hata yönetimi"
echo "   - FFmpeg entegrasyonu"
echo "   - H.264 parsing"
echo ""

echo -e "${MAGENTA}2. INTEGRATION TESTS${NC}   - Module entegrasyonu"
echo "   - API sözleşmeleri"
echo "   - Video sources entegrasyonu"
echo "   - Hardware model entegrasyonu"
echo "   - Veri akışı bütünlüğü"
echo "   - Durum makinesi uyumluluğu"
echo "   - Bellek güvenliği"
echo "   - Yapılandırma parametreleri"
echo ""

echo -e "${MAGENTA}3. REAL DEVICE TESTS${NC}   - Gerçek/simüle donanım"
echo "   - Device detection"
echo "   - FFmpeg komut doğrulama"
echo "   - Thread stress test"
echo "   - Ring buffer simülasyonu"
echo "   - NAL unit parsing"
echo "   - Performans metrikleri"
echo ""

echo -e "${YELLOW}Başlamak için Enter'a basın... (Ctrl+C = iptal)${NC}"
read -r

# ============ RUN ADVANCED TESTS ============
echo ""
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} TEST 1/3: ADVANCED TESTS${NC}"
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo ""

if [ -x "code/r_tests/test_usb_advanced.sh" ]; then
    bash code/r_tests/test_usb_advanced.sh
    ADVANCED_EXIT=$?
else
    echo -e "${RED}test_usb_advanced.sh çalıştırılabilir değil${NC}"
    chmod +x code/r_tests/test_usb_advanced.sh
    bash code/r_tests/test_usb_advanced.sh
    ADVANCED_EXIT=$?
fi

echo -e "${YELLOW}Advanced testleri bitirdik. Entegrasyon testlerine devam etmek için Enter'a basın...${NC}"
read -r

# ============ RUN INTEGRATION TESTS ============
echo ""
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} TEST 2/3: INTEGRATION TESTS${NC}"
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo ""

if [ -x "code/r_tests/test_usb_integration.sh" ]; then
    bash code/r_tests/test_usb_integration.sh
    INTEGRATION_EXIT=$?
else
    echo -e "${RED}test_usb_integration.sh çalıştırılabilir değil${NC}"
    chmod +x code/r_tests/test_usb_integration.sh
    bash code/r_tests/test_usb_integration.sh
    INTEGRATION_EXIT=$?
fi

echo -e "${YELLOW}Entegrasyon testlerini bitirdik. Gerçek device testlerine devam etmek için Enter'a basın...${NC}"
read -r

# ============ RUN REAL DEVICE TESTS ============
echo ""
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} TEST 3/3: REAL DEVICE TESTS${NC}"
echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
echo ""

if [ -x "code/r_tests/test_usb_real_device.sh" ]; then
    bash code/r_tests/test_usb_real_device.sh
    DEVICE_EXIT=$?
else
    echo -e "${RED}test_usb_real_device.sh çalıştırılabilir değil${NC}"
    chmod +x code/r_tests/test_usb_real_device.sh
    bash code/r_tests/test_usb_real_device.sh
    DEVICE_EXIT=$?
fi

# ============ FINAL SUMMARY ============
echo ""
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                   FINAL TEST SUMMARY                   ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "Test Suite Status:"
echo -e "  Advanced Tests     : $([ $ADVANCED_EXIT -eq 0 ] && echo -e "${GREEN}✓ PASSED${NC}" || echo -e "${RED}✗ FAILED${NC}")"
echo -e "  Integration Tests  : $([ $INTEGRATION_EXIT -eq 0 ] && echo -e "${GREEN}✓ PASSED${NC}" || echo -e "${RED}✗ FAILED${NC}")"
echo -e "  Device Tests       : $([ $DEVICE_EXIT -eq 0 ] && echo -e "${GREEN}✓ PASSED${NC}" || echo -e "${RED}✗ FAILED${NC}")"
echo ""

TOTAL_EXIT=$((ADVANCED_EXIT + INTEGRATION_EXIT + DEVICE_EXIT))

if [ $TOTAL_EXIT -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}    🎉 TÜM TESTLER BAŞARILI - USB MODÜLÜ HAZIR! 🎉      ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Sonraki adımlar:"
    echo "  1. make clean && make vehicle ile projeyi derle"
    echo "  2. USB kamerayı cihaza bağla"
    echo "  3. Uygulamayı çalıştır"
    echo ""
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  Bazı testler başarısız oldu - kontrol et             ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Hata ayıklama:"
    echo "  - Yukarıdaki çıktıları dikkatlice oku"
    echo "  - Kırmızı ✗ işaretlerini kontrol et"
    echo "  - İlgili test dosyasını tekrar çalıştır"
    echo ""
fi

exit $TOTAL_EXIT
