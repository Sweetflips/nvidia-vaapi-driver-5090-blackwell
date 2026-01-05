# nvidia-vaapi-driver

**Exclusive to Sweetflips** — RTX 5090 Blackwell fork with GB202/GB203 support for kernel 6.17+

VA-API implementation using NVDEC backend. Built for Firefox hardware-accelerated web video decode. Other applications untested.

# Table of contents

- [nvidia-vaapi-driver](#nvidia-vaapi-driver)
- [Table of contents](#table-of-contents)
- [Codec Support](#codec-support)
- [GPU Generation Support](#gpu-generation-support)
- [Installation](#installation)
  - [Packaging status](#packaging-status)
  - [Building](#building)
  - [Removal](#removal)
- [Configuration](#configuration)
  - [Upstream regressions](#upstream-regressions)
  - [Kernel parameters](#kernel-parameters)
  - [Environment Variables](#environment-variables)
  - [Firefox](#firefox)
  - [Chromium-Based Browsers](#chromium-based-browsers)
  - [MPV](#mpv)
  - [Direct Backend](#direct-backend)
- [Testing](#testing)
- [Blackwell-Specific Notes](#blackwell-specific-notes)

# Codec Support

Hardware decoding only. Encoding [not supported](/../../issues/116).

| Codec | Status | Notes |
|---|---|---|
| AV1 | ✓ | Firefox 98+ required |
| H.264 | ✓ | |
| HEVC | ✓ | Some distros ship Firefox/FFMPEG with HEVC disabled (patent concerns) |
| VP8 | ✓ | |
| VP9 | ✓ | Requires `gstreamer-codecparsers-1.0` at compile time |
| MPEG-2 | ✓ | |
| VC-1 | ✓ | |
| MPEG-4 | ✗ | VA-API lacks sufficient bitstream data for NVDEC |
| JPEG | ✗ | API mismatch prevents implementation |

YUV444 requirements:
- Turing or newer (20XX/16XX/30XX/40XX/50XX including Blackwell)
- HEVC codec
- Direct backend

# GPU Generation Support

| Generation | Series | Status | Driver Requirement |
|---|---|---|---|
| Kepler | GTX 600/700 | Supported | 470+ |
| Maxwell | GTX 900/Titan X | Supported | 470+ |
| Pascal | GTX 10XX | Supported | 470+ |
| Volta | Titan V | Supported | 470+ |
| Turing | RTX 20XX/GTX 16XX | Supported | 470+ |
| Ampere | RTX 30XX | Supported | 470+ |
| Ada Lovelace | RTX 40XX | Supported | 525+ |
| Blackwell | RTX 50XX (5090/5080) | Supported | 580+ |

Blackwell GPUs (GB202/GB203) require driver 580.0 or newer. Older drivers lack NVDEC interface definitions for these chips.

Check codec support: run `vainfo` with this driver, or see [NVIDIA's decode matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new#geforce).

# Installation

**Driver Requirements:**
- Series 470 or 500+ for pre-Blackwell
- Series 580+ for RTX 5090/5080 (Blackwell)

## Packaging status

<p align="top"><a href="https://repology.org/project/nvidia-vaapi-driver/versions"><img src="https://repology.org/badge/vertical-allrepos/nvidia-vaapi-driver.svg" alt="repology"><a href="https://repology.org/project/libva-nvidia-driver/versions"><img src="https://repology.org/badge/vertical-allrepos/libva-nvidia-driver.svg" alt="repology" align="top" width="%"></p>

[pkgs.org/nvidia-vaapi-driver](https://pkgs.org/search/?q=nvidia-vaapi-driver) | [pkgs.org/libva-nvidia-driver](https://pkgs.org/search/?q=libva-nvidia-driver)

openSUSE: [1](https://software.opensuse.org/package/nvidia-vaapi-driver), [2](https://software.opensuse.org/package/libva-nvidia-driver)

## Building

Dependencies: `meson`, `gstreamer-plugins-bad`, [`nv-codec-headers`](https://git.videolan.org/?p=ffmpeg/nv-codec-headers.git)

| Package manager | Required | Optional (additional codecs) |
|-----------------|----------|------------------------------|
| pacman | meson gst-plugins-bad ffnvcodec-headers | |
| apt | meson gstreamer1.0-plugins-bad libffmpeg-nvenc-dev libva-dev libegl-dev libdrm-dev | libgstreamer-plugins-bad1.0-dev |
| yum/dnf | meson libva-devel gstreamer1-plugins-bad-freeworld nv-codec-headers libdrm-devel | gstreamer1-plugins-bad-free-devel |

Build commands:

```sh
meson setup build
meson install -C build
```

## Removal

Default install location: `/usr/lib64/dri/nvidia_drv_video.so` (or `/usr/lib/x86_64-linux-gnu/dri/nvidia_drv_video.so` on Debian-based distros).

Delete this file to uninstall. If VDPAU-to-VAAPI driver was installed, restore symlink at `/usr/lib64/dri/vdpau_drv_video.so`.

# Configuration

## Upstream regressions

EGL backend broken on driver 525+. Use [direct backend](#direct-backend) instead.

Details: [upstream bug report](https://forums.developer.nvidia.com/t/cueglstreamproducerconnect-returns-error-801-on-525-53-driver/233610), [issue #126](/../../issues/126).

## Kernel parameters

Required kernel module parameter:

```
nvidia-drm.modeset=1
```

Set via [kernel parameters](https://wiki.archlinux.org/title/Kernel_parameters).

## Environment Variables

| Variable | Function |
|---|---|
| `NVD_LOG` | `1` = log to stdout. Any other value = append to that file path. |
| `NVD_MAX_INSTANCES` | Cap concurrent driver instances per-process. Useful for low-VRAM GPUs on video-heavy sites. |
| `NVD_BACKEND` | `egl` or `direct` (default). Direct bypasses broken EGL path on 525+ drivers. |

## Firefox

Firefox on Linux lacks HEVC due to licensing.

Minimum: Firefox 96, `ffmpeg` with VA-API support (`ffmpeg -hwaccels` must list `vaapi`).

**about:config settings:**

| Option | Value | Reason |
|---|---|---|
| media.ffmpeg.vaapi.enabled | true | Enables VA-API (required until Firefox 137) |
| media.hardware-video-decoding.force-enabled | true | Enables HW accel (required Firefox 137+) |
| media.rdd-ffmpeg.enabled | true | Forces ffmpeg into RDD process (default FF97+) |
| media.av1.enabled | false | Disable if GPU lacks AV1 to prevent software fallback |
| gfx.x11-egl.force-enabled | true | Driver requires EGL backend. Test with `MOZ_X11_EGL=1` first. |
| widget.dmabuf.force-enabled | true | Required on 470 series. DMA-BUF without GBM may cause partial failures. |

**Environment variables:**

| Variable | Value | Reason |
|---|---|---|
| MOZ_DISABLE_RDD_SANDBOX | 1 | Disables RDD process sandbox for decoder access |
| LIBVA_DRIVER_NAME | nvidia | Required for libva 2.20+. Forces this driver. |
| __EGL_VENDOR_LIBRARY_FILENAMES | /usr/share/glvnd/egl_vendor.d/10_nvidia.json | 470 series only. Prevents MESA driver selection. |
| CUDA_DISABLE_PERF_BOOST | 1 | Driver 580.105.08+. Reduces power during decode (equivalent to Windows CUDA Force P2). |

Suppress libva init spam by adding to `/etc/libva.conf`:
```
LIBVA_MESSAGING_LEVEL=1
```

Snap Firefox cannot access host-installed drivers.

## Chromium-Based Browsers

Supported: Chrome, Chromium, Thorium, Brave, Edge, Vivaldi, Opera

Driver auto-detects Chromium-based browsers via `/proc/self/exe` and applies format compatibility workarounds.

**Environment:**
```bash
export LIBVA_DRIVER_NAME=nvidia
export NVD_BACKEND=direct
export FORCENVDEC=1  # Force NVDEC path regardless of browser detection
```

**Launch flags (all Chromium browsers):**
```bash
# Chrome/Chromium
google-chrome \
  --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder \
  --disable-features=UseChromeOSDirectVideoDecoder \
  --use-gl=egl \
  --enable-gpu-rasterization

# Thorium (VA-API enabled by default, but add for explicit control)
thorium-browser \
  --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder \
  --use-gl=egl

# Brave
brave-browser \
  --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder \
  --disable-features=UseChromeOSDirectVideoDecoder \
  --use-gl=egl
```

**Troubleshooting zero NVDEC utilization:**

1. GPU sandbox blocking IOCTLs:
   ```bash
   google-chrome --disable-gpu-sandbox [other flags]
   ```
   Security tradeoff. Testing only.

2. Debug logging:
   ```bash
   NVD_LOG=1 thorium-browser [flags] 2>&1 | tee nvd-debug.log
   ```

3. Validation script:
   ```bash
   ./scripts/validate-nvdec.sh
   ```

**Streaming sites (Kick.com, Twitch, YouTube):**

Low Latency H.264/AV1 profiles use Blackwell's optimized power states. If utilization shows 0% but memory/encoder spikes, driver may crash during handover. Check `dmesg` for NVIDIA errors.

**Thorium-specific notes:**

Thorium ships with VA-API patches pre-applied. No additional chrome://flags configuration needed. Set environment variables and launch flags as above.

## MPV

Requires MPV 0.36.0+.

MPV already supports nvdec directly. This driver is only useful for testing. Use `test.sh` to run MPV with the built driver and correct environment.

## Direct Backend

Accesses NVIDIA kernel driver directly instead of EGL buffer sharing. Provides finer control over buffer allocation.

Tested: Kepler through Blackwell (including RTX 5090). Report issues at [#126](/../../issues/126) with `NVD_LOG=1` output.

This backend uses NVIDIA's unstable internal API. Kernel driver updates will break it. Headers from [open-gpu-kernel-modules](https://github.com/NVIDIA/open-gpu-kernel-modules) copied to `nvidia-include/` via `extract_headers.sh` and `headers.in`.

# Testing

Verify decoder activity:

**nvidia-settings:** Select GPU → check `Video Engine Utilization` (non-zero during playback).

**nvidia-smi:** Running during decode shows Firefox with `C` in `Type` column. `nvidia-smi pmon` shows per-process decode usage. `nvidia-smi dmon` shows per-GPU usage. Open kernel modules may misreport decode engine usage.

# Blackwell-Specific Notes

RTX 5090 (GB202) and RTX 5080 (GB203) require:

- Driver 580.0+ (NVDEC interface definitions added in this version)
- Kernel 6.17+ recommended for DRM compatibility
- Direct backend (`NVD_BACKEND=direct`)

PCI Device IDs added in this fork:
- GB202: 0x2684, 0x2685, 0x2686, 0x2687 (RTX 5090 variants)
- GB203: 0x2688, 0x2689, 0x268A, 0x268B (RTX 5080 variants)

NVENC detection is dynamic. Driver queries `nvEncodeAPIGetMaxSupportedVersion` at runtime instead of static capability tables.

Chrome browser detection implemented for format compatibility workarounds specific to Chromium's VA-API layer.

---

**Sweetflips Blackwell Compatibility Kernel Project**
https://github.com/Sweetflips/nvidia-vaapi-driver-5090-blackwell
