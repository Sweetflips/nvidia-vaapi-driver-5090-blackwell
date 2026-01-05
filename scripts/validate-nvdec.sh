#!/bin/bash
#
# NVIDIA VAAPI Driver Validation Script for Blackwell (RTX 5090)
# This script monitors IOCTL activity and NVDEC utilization during playback
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo " NVIDIA VAAPI Driver Validation Script"
echo " Blackwell (RTX 5090) Compatibility Test"
echo "=========================================="
echo

# Check if running as root for strace
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Note: Run as root for full IOCTL tracing${NC}"
fi

# Function to check driver version
check_driver_version() {
    echo "[1/6] Checking NVIDIA driver version..."
    if [ -f /proc/driver/nvidia/version ]; then
        DRIVER_VER=$(head -1 /proc/driver/nvidia/version | grep -oP '\d+\.\d+\.\d+' | head -1)
        MAJOR_VER=$(echo "$DRIVER_VER" | cut -d. -f1)
        echo -e "  Driver version: ${GREEN}$DRIVER_VER${NC}"
        
        if [ "$MAJOR_VER" -lt 580 ]; then
            echo -e "  ${YELLOW}Warning: Driver $MAJOR_VER < 580. Blackwell requires 580+${NC}"
        else
            echo -e "  ${GREEN}Driver version OK for Blackwell${NC}"
        fi
    else
        echo -e "  ${RED}Error: Cannot read driver version${NC}"
        return 1
    fi
}

# Function to check modeset parameter
check_modeset() {
    echo
    echo "[2/6] Checking nvidia-drm.modeset parameter..."
    if [ -f /sys/module/nvidia_drm/parameters/modeset ]; then
        MODESET=$(cat /sys/module/nvidia_drm/parameters/modeset)
        if [ "$MODESET" = "Y" ] || [ "$MODESET" = "1" ]; then
            echo -e "  ${GREEN}nvidia-drm.modeset=1 (OK)${NC}"
        else
            echo -e "  ${RED}nvidia-drm.modeset=0 (FAIL)${NC}"
            echo "  Add 'nvidia-drm.modeset=1' to kernel parameters"
            return 1
        fi
    else
        echo -e "  ${YELLOW}Cannot verify modeset parameter${NC}"
    fi
}

# Function to check VA-API driver
check_vaapi() {
    echo
    echo "[3/6] Checking VA-API driver..."
    if command -v vainfo &> /dev/null; then
        echo "  Running vainfo..."
        export LIBVA_DRIVER_NAME=nvidia
        export NVD_BACKEND=direct
        
        if vainfo 2>&1 | grep -q "nvidia"; then
            echo -e "  ${GREEN}NVIDIA VA-API driver loaded${NC}"
            
            # Check for profile support
            PROFILES=$(vainfo 2>&1 | grep -c "VAProfile" || true)
            echo -e "  Supported profiles: ${GREEN}$PROFILES${NC}"
            
            # Check for H.264 High Profile
            if vainfo 2>&1 | grep -q "VAProfileH264High"; then
                echo -e "  ${GREEN}H.264 High Profile: Supported${NC}"
            else
                echo -e "  ${YELLOW}H.264 High Profile: Not found${NC}"
            fi
            
            # Check for AV1
            if vainfo 2>&1 | grep -q "VAProfileAV1"; then
                echo -e "  ${GREEN}AV1: Supported${NC}"
            else
                echo -e "  ${YELLOW}AV1: Not found${NC}"
            fi
        else
            echo -e "  ${RED}NVIDIA VA-API driver not loaded${NC}"
            return 1
        fi
    else
        echo -e "  ${YELLOW}vainfo not installed${NC}"
    fi
}

# Function to check GPU architecture
check_gpu() {
    echo
    echo "[4/6] Checking GPU architecture..."
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        echo -e "  GPU: ${GREEN}$GPU_NAME${NC}"
        
        # Check for Blackwell (RTX 50 series)
        if echo "$GPU_NAME" | grep -qE "RTX 50[0-9][0-9]"; then
            echo -e "  ${GREEN}Blackwell architecture detected${NC}"
        elif echo "$GPU_NAME" | grep -qE "RTX 40[0-9][0-9]"; then
            echo -e "  ${GREEN}Ada Lovelace architecture detected${NC}"
        fi
    else
        echo -e "  ${YELLOW}nvidia-smi not available${NC}"
    fi
}

# Function to monitor NVDEC utilization
monitor_nvdec() {
    echo
    echo "[5/6] Monitoring NVDEC utilization (5 seconds)..."
    echo "  (Start playing a video in another window)"
    
    for i in {1..5}; do
        if command -v nvidia-smi &> /dev/null; then
            UTIL=$(nvidia-smi --query-gpu=utilization.decoder --format=csv,noheader 2>/dev/null | tr -d ' %')
            if [ -n "$UTIL" ] && [ "$UTIL" -gt 0 ]; then
                echo -e "  NVDEC utilization: ${GREEN}${UTIL}%${NC}"
            else
                echo -e "  NVDEC utilization: ${YELLOW}${UTIL:-0}%${NC}"
            fi
        fi
        sleep 1
    done
}

# Function to check for sandbox issues
check_sandbox() {
    echo
    echo "[6/6] Checking for potential sandbox issues..."
    
    # Check if /dev/nvidiactl is accessible
    if [ -c /dev/nvidiactl ]; then
        echo -e "  ${GREEN}/dev/nvidiactl accessible${NC}"
    else
        echo -e "  ${RED}/dev/nvidiactl not accessible${NC}"
    fi
    
    # Check if /dev/nvidia0 is accessible
    if [ -c /dev/nvidia0 ]; then
        echo -e "  ${GREEN}/dev/nvidia0 accessible${NC}"
    else
        echo -e "  ${RED}/dev/nvidia0 not accessible${NC}"
    fi
    
    # Check DRI render node
    if [ -c /dev/dri/renderD128 ]; then
        echo -e "  ${GREEN}/dev/dri/renderD128 accessible${NC}"
    else
        echo -e "  ${RED}DRI render node not accessible${NC}"
    fi
}

# Function to display Chrome launch command
show_chrome_flags() {
    echo
    echo "=========================================="
    echo " Chrome Launch Flags for RTX 5090"
    echo "=========================================="
    echo
    echo "Recommended environment variables:"
    echo -e "  ${GREEN}export LIBVA_DRIVER_NAME=nvidia${NC}"
    echo -e "  ${GREEN}export NVD_BACKEND=direct${NC}"
    echo -e "  ${GREEN}export NVD_LOG=1${NC}  # For debugging"
    echo
    echo "Recommended Chrome flags:"
    echo -e "  ${GREEN}--enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder${NC}"
    echo -e "  ${GREEN}--disable-features=UseChromeOSDirectVideoDecoder${NC}"
    echo -e "  ${GREEN}--use-gl=egl${NC}"
    echo -e "  ${GREEN}--enable-gpu-rasterization${NC}"
    echo
    echo "If 0% utilization persists, add:"
    echo -e "  ${YELLOW}--disable-gpu-sandbox${NC}  # Security trade-off"
    echo
    echo "Full command:"
    echo "  google-chrome \\"
    echo "    --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder \\"
    echo "    --disable-features=UseChromeOSDirectVideoDecoder \\"
    echo "    --use-gl=egl \\"
    echo "    --enable-gpu-rasterization"
    echo
}

# Function to trace IOCTL calls (requires root)
trace_ioctl() {
    echo
    echo "=========================================="
    echo " IOCTL Trace (requires root)"
    echo "=========================================="
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Skipping IOCTL trace (not root)${NC}"
        return
    fi
    
    if ! command -v strace &> /dev/null; then
        echo -e "${YELLOW}strace not installed${NC}"
        return
    fi
    
    echo "To trace IOCTL calls during Chrome playback:"
    echo "  strace -e ioctl -f -p \$(pgrep -f 'chrome.*gpu-process') 2>&1 | grep -E 'nvidia|drm'"
    echo
}

# Run all checks
check_driver_version
check_modeset
check_vaapi
check_gpu
monitor_nvdec
check_sandbox
show_chrome_flags
trace_ioctl

echo
echo "=========================================="
echo " Validation Complete"
echo "=========================================="
echo
echo "If NVDEC utilization is still 0%, enable debug logging:"
echo "  NVD_LOG=1 google-chrome [flags] 2>&1 | tee nvd-debug.log"
echo
echo "Check the log for:"
echo "  - 'Blackwell architecture detected'"
echo "  - 'sandbox' or 'EACCES' errors"
echo "  - 'GOB' or 'alloc_image' messages"
