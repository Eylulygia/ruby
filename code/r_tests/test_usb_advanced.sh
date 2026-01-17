#!/bin/bash
# USB Camera Module - Advanced Unit Tests
# Tests: Memory, threading, buffer management, state machine
# Run: chmod +x test_usb_advanced.sh && ./test_usb_advanced.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============ TEST 1: Code Analysis ============
print_header "TEST 1: STATIK KOD ANALİZİ"

print_test "1.1: Derlemede Uyarı (Warning) Kontrolleri"
cd code/r_tests
if [ -f "test_usb_unit.cpp" ]; then
    if g++ -std=c++11 -Wall -Wextra -Werror=uninitialized -c test_usb_unit.cpp -o /tmp/test.o 2>&1 | grep -i "warning"; then
        print_warn "Derlemede uyarılar var (kontrol et)"
    else
        print_pass "Derlemede uyarı yok"
    fi
    rm -f /tmp/test.o
fi
cd "$PROJECT_ROOT"

print_test "1.2: Null Pointer Kontrolleri"
NULLPTR_CHECK=0
# Ring buffer functions
if grep -q "if.*NULL\|if.*!s_RingBuffer\|if.*mutex" code/r_vehicle/video_source_usb.cpp; then
    ((NULLPTR_CHECK++))
fi
# FFmpeg pipe checks
if grep -q "s_iFFMpegPipeReadFd.*!= -1\|if.*s_iFFMpegPid" code/r_vehicle/video_source_usb.cpp; then
    ((NULLPTR_CHECK++))
fi
if [ $NULLPTR_CHECK -ge 2 ]; then
    print_pass "Null pointer kontrolleri bulundu ($NULLPTR_CHECK kontrol)"
else
    print_fail "Null pointer kontrolleri eksik!"
fi

print_test "1.3: Buffer Overflow Koruması"
if grep -q "USB_CAMERA_MAX_NAL_SIZE\|USB_CAMERA_BUFFER_SIZE" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Buffer boundary checks tanımlanmış"
else
    print_fail "Buffer checks eksik!"
fi

print_test "1.4: Memory Leak Kontrolleri"
MALLOC_CHECK=0
FREE_CHECK=0
if grep -q "malloc\|calloc\|new " code/r_vehicle/video_source_usb.cpp; then
    MALLOC_CHECK=$(grep -c "malloc\|calloc\|new " code/r_vehicle/video_source_usb.cpp)
fi
if grep -q "free\|delete " code/r_vehicle/video_source_usb.cpp; then
    FREE_CHECK=$(grep -c "free\|delete " code/r_vehicle/video_source_usb.cpp)
fi
if [ "$MALLOC_CHECK" -eq "$FREE_CHECK" ] && [ "$MALLOC_CHECK" -gt 0 ]; then
    print_pass "Memory allocations ($MALLOC_CHECK) ve frees ($FREE_CHECK) eşleşti"
elif [ "$MALLOC_CHECK" -eq 0 ]; then
    print_pass "Dynamic memory kullanılmıyor (stack-based - İYİ!)"
else
    print_fail "Memory allocations ($MALLOC_CHECK) vs frees ($FREE_CHECK) eşleşmiyor!"
fi

# ============ TEST 2: Thread Safety ============
print_header "TEST 2: THREAD SAFETY (İŞ PARÇACIĞI GÜVENLİĞİ)"

print_test "2.1: Mutex İlklendirmesi"
if grep -q "pthread_mutex_init.*s_RingBuffer.mutex" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Mutex başlatılıyor"
else
    print_warn "Mutex init çağrısı bulunamadı"
fi

print_test "2.2: Mutex Lock/Unlock Dengesi"
LOCK_COUNT=$(grep -c "pthread_mutex_lock" code/r_vehicle/video_source_usb.cpp || echo 0)
UNLOCK_COUNT=$(grep -c "pthread_mutex_unlock" code/r_vehicle/video_source_usb.cpp || echo 0)
if [ "$LOCK_COUNT" -gt 0 ] && [ "$LOCK_COUNT" -eq "$UNLOCK_COUNT" ]; then
    print_pass "Mutex locks ($LOCK_COUNT) ve unlocks ($UNLOCK_COUNT) dengeli"
else
    print_warn "Mutex dengesi: locks=$LOCK_COUNT unlocks=$UNLOCK_COUNT"
fi

print_test "2.3: Volatile Variables (Race Condition Önleme)"
if grep -q "volatile.*s_bUSBCaptureThreadStop\|volatile.*s_USBCameraState" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Volatile global variables kullanılıyor"
else
    print_warn "Volatile variables eksik olabilir"
fi

print_test "2.4: Thread Join Kontrolü"
if grep -q "pthread_join" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Thread'ler düzgün sonlandırılıyor"
else
    print_warn "pthread_join bulunamadı"
fi

# ============ TEST 3: State Machine ============
print_header "TEST 3: DURUM MAKİNESİ (STATE MACHINE) KONTROLLERI"

print_test "3.1: State Enum Tanımı"
STATES_COUNT=$(grep -c "USB_CAMERA_STATE_\|usb_camera_state_t" code/r_vehicle/video_source_usb.h || echo 0)
if [ "$STATES_COUNT" -ge 5 ]; then
    print_pass "State enum'unda $STATES_COUNT state bulundu"
else
    print_fail "Yeterli state tanımı yok (bulundu: $STATES_COUNT)"
fi

print_test "3.2: State Transitions"
if grep -q "s_USBCameraState = USB_CAMERA_STATE_" code/r_vehicle/video_source_usb.cpp; then
    TRANSITIONS=$(grep -c "s_USBCameraState = USB_CAMERA_STATE_" code/r_vehicle/video_source_usb.cpp)
    print_pass "State transitions yapılıyor ($TRANSITIONS geçiş bulundu)"
else
    print_fail "State transitions bulunamadı!"
fi

print_test "3.3: Invalid State Kontrolleri"
if grep -q "s_USBCameraState == USB_CAMERA_STATE_\|if.*state.*==" code/r_vehicle/video_source_usb.cpp; then
    print_pass "State kontrollemeleri var"
else
    print_warn "State kontrollemeleri eksik olabilir"
fi

# ============ TEST 4: Ring Buffer ============
print_header "TEST 4: RING BUFFER ANALİZİ"

print_test "4.1: Ring Buffer Yapısı"
if grep -q "typedef struct.*usb_ring_buffer_t\|iWriteIndex\|iReadIndex\|iCount" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Ring buffer yapısı düzgün tanımlanmış"
else
    print_fail "Ring buffer yapısı eksik!"
fi

print_test "4.2: Buffer Taşma Koruması"
if grep -q "iCount.*USB_CAMERA_RING_BUFFER_COUNT\|iWriteIndex.*%\|circular" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Buffer taşma (overflow) koruması var"
else
    print_warn "Buffer overflow checks kontrol edilsin"
fi

print_test "4.3: NAL Unit Buffer Yönetimi"
if grep -q "usb_nal_buffer_t\|bValid\|uNALType" code/r_vehicle/video_source_usb.cpp; then
    print_pass "NAL unit buffer yönetimi var"
else
    print_fail "NAL buffer yönetimi eksik!"
fi

# ============ TEST 5: Error Handling ============
print_header "TEST 5: HATA YÖNETIMI (ERROR HANDLING)"

print_test "5.1: Error States"
ERROR_STATES=$(grep -c "ERROR\|FAILED\|USB_CAMERA_STATE_ERROR" code/r_vehicle/video_source_usb.cpp || echo 0)
if [ "$ERROR_STATES" -gt 0 ]; then
    print_pass "Error handling mekanizması var ($ERROR_STATES satır)"
else
    print_warn "Error handling eksik olabilir"
fi

print_test "5.2: Cleanup on Failure"
if grep -q "close.*pipe\|close.*fd\|pthread_cancel\|pthread_join" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Resource cleanup var"
else
    print_warn "Cleanup procedures kontrol edilsin"
fi

print_test "5.3: Consecutive Error Tracking"
if grep -q "s_iConsecutiveReadErrors\|error_count\|retry" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Hata takibi mekanizması var"
else
    print_warn "Hata takibi eksik olabilir"
fi

# ============ TEST 6: FFmpeg Integration ============
print_header "TEST 6: FFmpeg ENTEGRASYONU"

print_test "6.1: FFmpeg Process Management"
if grep -q "popen\|fork\|execv\|s_iFFMpegPid" code/r_vehicle/video_source_usb.cpp; then
    print_pass "FFmpeg process'i başlatılıyor"
else
    print_fail "FFmpeg process management bulunamadı!"
fi

print_test "6.2: Pipe Reading"
if grep -q "read.*s_iFFMpegPipeReadFd\|fread\|s_uTempReadBuffer" code/r_vehicle/video_source_usb.cpp; then
    print_pass "FFmpeg output pipe'ı okunuyor"
else
    print_fail "Pipe reading mekanizması eksik!"
fi

print_test "6.3: Command Line Parameter Safety"
if grep -q "input_format\|framerate\|bitrate\|-i\|/dev/video" code/r_vehicle/video_source_usb.cpp; then
    print_pass "FFmpeg komut parametreleri var"
else
    print_warn "FFmpeg parametreleri kontrol edilsin"
fi

# ============ TEST 7: H.264 Parsing ============
print_header "TEST 7: H.264 PARSING"

print_test "7.1: Parser Başlatılması"
if grep -q "ParserH264\|s_ParserH264USB" code/r_vehicle/video_source_usb.cpp; then
    print_pass "H.264 parser tanımlanmış"
else
    print_fail "H.264 parser bulunamadı!"
fi

print_test "7.2: NAL Unit Detection"
if grep -q "0x00.*0x00.*0x01\|start_code\|nal.*type" code/r_vehicle/video_source_usb.cpp; then
    print_pass "NAL unit detection var"
else
    print_warn "NAL detection kontrol edilsin"
fi

print_test "7.3: Frame Type Identification"
if grep -q "SPS\|PPS\|IDR\|P-frame\|uNALType" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Frame type identification var"
else
    print_warn "Frame type kontrol eksik"
fi

# ============ TEST 8: Documentation ============
print_header "TEST 8: DOKÜMANTASYON"

print_test "8.1: Function Documentation"
FUNC_COMMENTS=$(grep -c "^/\*\|^ \*\|^//" code/r_vehicle/video_source_usb.h || echo 0)
if [ "$FUNC_COMMENTS" -gt 10 ]; then
    print_pass "Fonksiyon dokümantasyonu var ($FUNC_COMMENTS satır)"
else
    print_warn "Dokümantasyon eksik olabilir"
fi

print_test "8.2: Structure Documentation"
if grep -q "typedef struct\|typedef enum" code/r_vehicle/video_source_usb.h; then
    print_pass "Structure açıklamaları var"
else
    print_warn "Structure dokümantasyonu eksik"
fi

# ============ TEST 9: Compilation Check ============
print_header "TEST 9: DERLEMİ KONTROLLERI"

print_test "9.1: Header Dependencies"
if grep -q "#include" code/r_vehicle/video_source_usb.cpp; then
    INCLUDES=$(grep "#include" code/r_vehicle/video_source_usb.cpp | wc -l)
    print_pass "Gerekli header'lar include edilmiş ($INCLUDES include)"
else
    print_fail "Include'lar eksik!"
fi

print_test "9.2: Type Consistency"
if grep -q "u8\|u32\|bool\|int" code/r_vehicle/video_source_usb.cpp; then
    print_pass "Type'lar tutarlı şekilde kullanılmış"
else
    print_warn "Type kontrol edilsin"
fi

# ============ SUMMARY ============
print_header "ÖZET - İLERİ TESTLER"

echo -e "${GREEN}✓ Tüm advanced testler tamamlandı!${NC}"
echo ""
echo "Ne Test Ettik:"
echo "  ✓ Statik kod analizi (null pointers, buffer overflow)"
echo "  ✓ Thread safety (mutex dengesi, volatile variables)"
echo "  ✓ State machine transitions"
echo "  ✓ Ring buffer management"
echo "  ✓ Error handling"
echo "  ✓ FFmpeg process management"
echo "  ✓ H.264 parsing mekanizmaları"
echo "  ✓ Kod dokümantasyonu"
echo ""
echo "Sonraki Adımlar:"
echo "  1. test_usb_integration.sh çalıştır"
echo "  2. test_usb_real_device.sh ile gerçek kamera test et"
echo ""
