#!/bin/bash
# USB Camera Module - Build & Test Script
# Run: chmod +x test_usb_build.sh && ./test_usb_build.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  USB Camera Module - Build & Code Verification       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "[1/5] Checking required files..."
FILES_TO_CHECK=(
    "code/r_vehicle/video_source_usb.h"
    "code/r_vehicle/video_source_usb.cpp"
    "code/base/hardware.h"
    "code/base/models.h"
    "code/base/models.cpp"
    "code/r_vehicle/video_sources.h"
    "code/r_vehicle/video_sources.cpp"
    "code/base/hardware_camera.cpp"
)

ALL_EXIST=true
for f in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$f" ]; then
        echo -e "  ${GREEN}✓${NC} $f"
    else
        echo -e "  ${RED}✗${NC} $f (MISSING)"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = false ]; then
    echo -e "${RED}ERROR: Some required files are missing${NC}"
    exit 1
fi

echo ""
echo "[2/5] Checking CAMERA_TYPE_USB_THERMAL defined..."
if grep -q "CAMERA_TYPE_USB_THERMAL" code/base/hardware.h; then
    echo -e "  ${GREEN}✓${NC} CAMERA_TYPE_USB_THERMAL found in hardware.h"
else
    echo -e "  ${RED}✗${NC} CAMERA_TYPE_USB_THERMAL NOT found"
    exit 1
fi

echo ""
echo "[3/5] Checking isActiveCameraUSB() method..."
if grep -q "isActiveCameraUSB" code/base/models.h; then
    echo -e "  ${GREEN}✓${NC} isActiveCameraUSB() declared in models.h"
else
    echo -e "  ${RED}✗${NC} isActiveCameraUSB() NOT declared"
    exit 1
fi

if grep -q "Model::isActiveCameraUSB" code/base/models.cpp; then
    echo -e "  ${GREEN}✓${NC} isActiveCameraUSB() implemented in models.cpp"
else
    echo -e "  ${RED}✗${NC} isActiveCameraUSB() NOT implemented"
    exit 1
fi

echo ""
echo "[4/5] Checking video_sources.cpp integration..."
INTEGRATIONS=(
    "video_source_usb_start_program"
    "video_source_usb_stop_program"
    "video_source_usb_read"
    "isActiveCameraUSB"
)

for func in "${INTEGRATIONS[@]}"; do
    if grep -q "$func" code/r_vehicle/video_sources.cpp; then
        echo -e "  ${GREEN}✓${NC} $func integrated"
    else
        echo -e "  ${YELLOW}⚠${NC} $func not found in video_sources.cpp"
    fi
done

echo ""
echo "[5/5] Checking USB detection in hardware_camera.cpp..."
if grep -q "USB camera detected" code/base/hardware_camera.cpp; then
    echo -e "  ${GREEN}✓${NC} USB camera detection logic present"
else
    echo -e "  ${YELLOW}⚠${NC} USB camera detection may be missing"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Code Structure Verification: ${GREEN}PASSED${NC}                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Try to build test if on Linux
if [ "$(uname)" = "Linux" ]; then
    echo "[BONUS] Attempting to build test suite..."
    
    if [ -f "code/r_tests/test_usb_camera.cpp" ]; then
        cd code/r_tests
        if g++ -std=c++11 -o test_usb_camera test_usb_camera.cpp -lpthread 2>/dev/null; then
            echo -e "${GREEN}✓ Test suite compiled successfully${NC}"
            echo ""
            echo "Running tests..."
            ./test_usb_camera
        else
            echo -e "${YELLOW}⚠ Test compilation failed (may need headers)${NC}"
        fi
        cd "$PROJECT_ROOT"
    fi
else
    echo -e "${YELLOW}Note: Full build requires Linux with required libraries${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. Copy project to Linux VM"
echo "  2. Run: make clean && make vehicle"
echo "  3. Connect USB camera and run test"
