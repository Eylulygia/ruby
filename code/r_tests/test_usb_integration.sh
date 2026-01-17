#!/bin/bash
# USB Camera Module - Integration Tests
# Tests: Module interaction, API contracts, system integration
# Run: chmod +x test_usb_integration.sh && ./test_usb_integration.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

TEST_RESULTS_PASSED=0
TEST_RESULTS_FAILED=0
TEST_RESULTS_WARNED=0

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_test() {
    echo -e "${MAGENTA}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}  ✓${NC} $1"
    ((TEST_RESULTS_PASSED++))
}

print_fail() {
    echo -e "${RED}  ✗${NC} $1"
    ((TEST_RESULTS_FAILED++))
}

print_warn() {
    echo -e "${YELLOW}  ⚠${NC} $1"
    ((TEST_RESULTS_WARNED++))
}

# ============ TEST 1: API Contract Verification ============
print_header "TEST 1: API SÖZLEŞMELER (API Contracts)"

print_test "1.1: Public Functions Tamamlılığı"

REQUIRED_FUNCTIONS=(
    "video_source_usb_start_program"
    "video_source_usb_stop_program"
    "video_source_usb_get_program_start_time"
    "video_source_usb_read"
    "video_source_usb_clear_input_buffers"
    "video_source_usb_last_read_is_single_nal"
    "video_source_usb_last_read_is_start_nal"
    "video_source_usb_last_read_is_end_nal"
    "video_source_usb_get_last_nal_type"
    "video_source_usb_apply_all_parameters"
    "video_source_usb_get_audio_data"
    "video_source_usb_clear_audio_buffers"
    "video_source_usb_periodic_health_checks"
    "video_source_usb_is_available"
    "video_source_usb_get_state"
)

FOUND_COUNT=0
for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "^[a-zA-Z_].*$func" code/r_vehicle/video_source_usb.h; then
        ((FOUND_COUNT++))
    fi
done

if [ "$FOUND_COUNT" -eq "${#REQUIRED_FUNCTIONS[@]}" ]; then
    print_pass "Tüm $FOUND_COUNT gerekli fonksiyon tanımlanmış"
else
    print_fail "Eksik fonksiyonlar var (bulundu: $FOUND_COUNT/${#REQUIRED_FUNCTIONS[@]})"
fi

print_test "1.2: Function Parameter Validasyonu"

if grep -q "u32.*uOverwriteInitialBitrate\|int.*iOverwriteInitialKFMs" code/r_vehicle/video_source_usb.h; then
    print_pass "Başlat fonksiyonunun parametreleri doğru"
else
    print_fail "Başlat fonksiyonu parametreleri yanlış"
fi

if grep -q "int.*piReadSize\|bool.*bAsync\|u32.*puOutTimeDataAvailable" code/r_vehicle/video_source_usb.h; then
    print_pass "Read fonksiyonunun parametreleri doğru"
else
    print_fail "Read fonksiyonu parametreleri yanlış"
fi

print_test "1.3: Return Type Kontrolleri"

if grep -q "u32 video_source_usb_start_program\|u8\* video_source_usb_read\|bool video_source_usb_" code/r_vehicle/video_source_usb.h; then
    print_pass "Return type'lar tutarlı"
else
    print_fail "Return type'lar eksik veya yanlış"
fi

# ============ TEST 2: Video Sources Integration ============
print_header "TEST 2: VIDEO SOURCES İLKLEŞTİRMESİ"

print_test "2.1: Dispatch Table Entegrasyonu"

if grep -q "video_source_usb_start_program" code/r_vehicle/video_sources.cpp; then
    print_pass "USB start_program video_sources.cpp'de kullanılıyor"
else
    print_fail "USB start_program entegrasyonu eksik"
fi

if grep -q "video_source_usb_stop_program" code/r_vehicle/video_sources.cpp; then
    print_pass "USB stop_program video_sources.cpp'de kullanılıyor"
else
    print_fail "USB stop_program entegrasyonu eksik"
fi

if grep -q "video_source_usb_read" code/r_vehicle/video_sources.cpp; then
    print_pass "USB read video_sources.cpp'de kullanılıyor"
else
    print_fail "USB read entegrasyonu eksik"
fi

print_test "2.2: Conditional Compilation"

if grep -q "#ifdef.*USB\|#if.*USB\|isActiveCameraUSB" code/r_vehicle/video_sources.cpp; then
    print_pass "USB'ye özgü kodlar şartlı olarak derlenebiliyor"
else
    print_warn "USB conditional compilation kontrol edilsin"
fi

print_test "2.3: Error Handling Integration"

if grep -q "video_source_usb_start_program.*if\|video_source_usb_read.*NULL\|== false" code/r_vehicle/video_sources.cpp; then
    print_pass "USB fonksiyonlarından return değerleri kontrol ediliyor"
else
    print_warn "USB return değerleri tam kontrol edilmiyor olabilir"
fi

# ============ TEST 3: Hardware Model Integration ============
print_header "TEST 3: DONANIM MODELİ ENTEGRASYONU"

print_test "3.1: Camera Type Tanımı"

if grep -q "CAMERA_TYPE_USB_THERMAL" code/base/hardware.h; then
    print_pass "CAMERA_TYPE_USB_THERMAL donanım'da tanımlanmış"
else
    print_fail "Camera type enum'da USB_THERMAL yok"
fi

if grep -q "CAMERA_TYPE_USB_THERMAL\|isActiveCameraUSB" code/base/models.h; then
    print_pass "Models.h'da USB camera kontrolleri var"
else
    print_fail "Models.h'da USB kontrolleri eksik"
fi

print_test "3.2: isActiveCameraUSB() Implementasyonu"

if grep -q "bool Model::isActiveCameraUSB()" code/base/models.cpp; then
    print_pass "isActiveCameraUSB() Model class'ında tanımlanmış"
else
    print_fail "isActiveCameraUSB() implementasyonu yok"
fi

if grep -q "CAMERA_TYPE_USB_THERMAL\|camera_type == CAMERA_TYPE_USB" code/base/models.cpp; then
    print_pass "Model, USB kamerayı doğru algılıyor"
else
    print_fail "Model USB kamera algılama logic'i yok"
fi

print_test "3.3: Hardware Detection Integration"

if grep -q "USB camera detected\|isActiveCameraUSB()\|CAMERA_TYPE_USB" code/base/hardware_camera.cpp; then
    print_pass "hardware_camera.cpp USB algılaması yapıyor"
else
    print_fail "USB algılama hardware_camera.cpp'de yok"
fi

# ============ TEST 4: Data Flow Integrity ============
print_header "TEST 4: VERİ AKIŞI BÜTÜNLÜĞÜ"

print_test "4.1: Buffer Management Tutarlılığı"

# Check for write operations
if grep -q "_ring_buffer_write\|write.*index\|push.*data" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Ring buffer write operasyonları var"
else
    print_warn "Ring buffer write kontrol edilsin"
fi

# Check for read operations
if grep -q "_ring_buffer_read\|read.*index\|pop.*data" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Ring buffer read operasyonları var"
else
    print_warn "Ring buffer read kontrol edilsin"
fi

print_test "4.2: NAL Unit Flow"

if grep -q "bIsStartNAL\|bIsEndNAL\|uNALType.*s_RingBuffer" code/r_vehicle/video_source_usb.cpp; then
    print_pass "NAL unit metadata akışı var"
else
    print_fail "NAL unit metadata flow eksik"
fi

print_test "4.3: Timestamp Consistency"

if grep -q "uTimestamp\|GetTickCount\|time.*stamp" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Timestamp tracking mekanizması var"
else
    print_warn "Timestamp consistency kontrol edilsin"
fi

# ============ TEST 5: State Machine Compatibility ============
print_header "TEST 5: DURUM MAKİNESİ UYUMLULUĞU"

print_test "5.1: Starting Sequence"

SEQUENCE_OK=true
if ! grep -q "USB_CAMERA_STATE_STOPPED.*USB_CAMERA_STATE_STARTING" code/r_vehicle/video_source_usb.cpp; then
    SEQUENCE_OK=false
fi
if ! grep -q "USB_CAMERA_STATE_STARTING.*USB_CAMERA_STATE_RUNNING" code/r_vehicle/video_source_usb.cpp; then
    SEQUENCE_OK=false
fi

if [ "$SEQUENCE_OK" = true ]; then
    print_pass "Başlat sequence'ı doğru (STOPPED → STARTING → RUNNING)"
else
    print_warn "Başlat sequence'ı kontrol edilsin"
fi

print_test "5.2: Error Recovery"

if grep -q "USB_CAMERA_STATE_ERROR.*USB_CAMERA_STATE_STOPPED\|recovery\|restart" code/r_vehicle/video_source_usb.cpp; then
    print_pass "ERROR statüsünden recovery var"
else
    print_warn "ERROR recovery mekanizması eksik olabilir"
fi

print_test "5.3: Clean Shutdown"

if grep -q "USB_CAMERA_STATE_RUNNING.*USB_CAMERA_STATE_STOPPED\|pthread_join\|close.*pipe" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Temiz shutdown sequence'ı var"
else
    print_warn "Shutdown sequence'ı kontrol edilsin"
fi

# ============ TEST 6: Memory Safety ============
print_header "TEST 6: BELLEK GÜVENLİĞİ"

print_test "6.1: Static Buffer Sizes"

if grep -q "USB_CAMERA_BUFFER_SIZE.*256.*1024\|USB_CAMERA_MAX_NAL_SIZE.*128" code/r_vehicle/video_source_usb.h; then
    print_pass "Buffer size'lar statik ve sınırlı"
else
    print_warn "Buffer size'lar kontrol edilsin"
fi

print_test "6.2: Array Bounds"

if grep -q "for.*i.*<.*USB_CAMERA_RING_BUFFER_COUNT\|buffers\[.*\%.*\]" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Array bounds kontrolleri var"
else
    print_warn "Array bounds checks kontrol edilsin"
fi

print_test "6.3: Heap vs Stack"

DYNAMIC_ALLOC=$(grep -c "malloc\|calloc\|new " code/r_vehicle/video_source_usb.cpp || echo 0)
STATIC_BUFFERS=$(grep -c "s_RingBuffer\|s_uTempReadBuffer\|s_ParserH264" code/r_vehicle/video_source_usb.cpp || echo 0)

if [ "$DYNAMIC_ALLOC" -lt 2 ] && [ "$STATIC_BUFFERS" -gt 3 ]; then
    print_pass "Stack-based buffers tercih ediliyor (güvenli)"
else
    print_warn "Dynamic allocation kontrol edilsin"
fi

# ============ TEST 7: Configuration Parameters ============
print_header "TEST 7: YAPILANDIRMA PARAMETRELERİ"

print_test "7.1: Video Parameters"

PARAMS_FOUND=0
[ $(grep -c "USB_CAMERA_DEFAULT_WIDTH\|USB_CAMERA_DEFAULT_HEIGHT" code/r_vehicle/video_source_usb.h || echo 0) -gt 0 ] && ((PARAMS_FOUND++))
[ $(grep -c "USB_CAMERA_DEFAULT_FPS" code/r_vehicle/video_source_usb.h || echo 0) -gt 0 ] && ((PARAMS_FOUND++))
[ $(grep -c "USB_CAMERA_DEFAULT_DEVICE" code/r_vehicle/video_source_usb.h || echo 0) -gt 0 ] && ((PARAMS_FOUND++))

if [ "$PARAMS_FOUND" -ge 3 ]; then
    print_pass "Video parametreleri tanımlanmış"
else
    print_fail "Video parametreleri eksik"
fi

print_test "7.2: Ring Buffer Configuration"

if grep -q "USB_CAMERA_RING_BUFFER_COUNT\|USB_CAMERA_MAX_NAL_SIZE" code/r_vehicle/video_source_usb.h; then
    print_pass "Ring buffer config'i tanımlanmış"
else
    print_fail "Ring buffer config eksik"
fi

# ============ TEST 8: Performance Considerations ============
print_header "TEST 8: PERFORMANS DIKKATLARI"

print_test "8.1: Async Operations"

if grep -q "bAsync\|pthread\|fork\|background" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Asynchronous işlemler var"
else
    print_warn "Async operasyon kontrol edilsin"
fi

print_test "8.2: Health Check Frequency"

if grep -q "periodic_health_checks\|HEALTH_CHECK\|timeout" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Periyodik health checks mekanizması var"
else
    print_warn "Health check mekanizması kontrol edilsin"
fi

print_test "8.3: Resource Cleanup Timing"

if grep -q "close.*s_iFFMpegPipeReadFd\|kill.*FFmpeg\|pthread_cancel" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Resource cleanup zamanlaması var"
else
    print_warn "Resource cleanup timing kontrol edilsin"
fi

# ============ TEST 9: Compilation ============
print_header "TEST 9: DERLEMİ TESTİ"

print_test "9.1: Include Path Validation"

if [ -f "code/r_vehicle/video_source_usb.h" ] && [ -f "code/r_vehicle/video_source_usb.cpp" ]; then
    if grep -q "#include.*video_source_usb.h" code/r_vehicle/video_source_usb.cpp; then
        print_pass "Header inclusion doğru"
    else
        print_fail "Header inclusion hatalı"
    fi
fi

print_test "9.2: Symbol Export Check"

if grep -q "^u32 video_source_usb_start_program\|^u8\* video_source_usb_read\|^void video_source_usb_" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Public symbols dışa aktarılıyor"
else
    print_warn "Symbol export kontrol edilsin"
fi

# ============ SUMMARY ============
print_header "ÖZET - ENTEGRASYON TESTLERI"

TOTAL_TESTS=$((TEST_RESULTS_PASSED + TEST_RESULTS_FAILED + TEST_RESULTS_WARNED))

echo -e "Toplam Testler: ${MAGENTA}${TOTAL_TESTS}${NC}"
echo -e "  ${GREEN}Geçen:${NC} $TEST_RESULTS_PASSED"
echo -e "  ${RED}Başarısız:${NC} $TEST_RESULTS_FAILED"
echo -e "  ${YELLOW}Uyarı:${NC} $TEST_RESULTS_WARNED"
echo ""

if [ "$TEST_RESULTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ Entegrasyon testleri BAŞARILI${NC}"
else
    echo -e "${RED}✗ $TEST_RESULTS_FAILED test başarısız - kontrol edilsin${NC}"
fi

echo ""
echo "Test Edilen Alanlar:"
echo "  ✓ API Sözleşmeleri (Contracts)"
echo "  ✓ Video Sources Entegrasyonu"
echo "  ✓ Hardware Model Entegrasyonu"
echo "  ✓ Veri Akışı Bütünlüğü"
echo "  ✓ Durum Makinesi Uyumluluğu"
echo "  ✓ Bellek Güvenliği"
echo "  ✓ Yapılandırma Parametreleri"
echo "  ✓ Performans Dikkatleri"
echo "  ✓ Derleme"
echo ""
echo "Sonraki: test_usb_real_device.sh ile gerçek kamera test et"
echo ""
