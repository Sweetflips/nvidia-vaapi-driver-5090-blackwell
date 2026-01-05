#ifndef NV_DRIVER_H
#define NV_DRIVER_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#include "../common.h"
#include "nvidia-drm-ioctl.h"
#include "../chrome_detect.h"

#define ROUND_UP(N, S) ((((N) + (S) - 1) / (S)) * (S))

/* GPU Architecture identifiers */
#define NV_GPU_ARCH_UNKNOWN     0
#define NV_GPU_ARCH_KEPLER      0x0E0
#define NV_GPU_ARCH_MAXWELL     0x110
#define NV_GPU_ARCH_PASCAL      0x130
#define NV_GPU_ARCH_VOLTA       0x140
#define NV_GPU_ARCH_TURING      0x160
#define NV_GPU_ARCH_AMPERE      0x170
#define NV_GPU_ARCH_ADA         0x190
#define NV_GPU_ARCH_HOPPER      0x180
#define NV_GPU_ARCH_BLACKWELL   0x1B0

/* Blackwell memory alignment requirements */
#define BLACKWELL_SURFACE_ALIGNMENT     512
#define BLACKWELL_PITCH_ALIGNMENT       256
#define BLACKWELL_PAGE_SIZE_LARGE       262144  /* 256KB */
#define BLACKWELL_PAGE_SIZE_STANDARD    65536   /* 64KB */

/* Blackwell-specific GOB parameters */
#define BLACKWELL_GOB_WIDTH             64
#define BLACKWELL_GOB_HEIGHT            8
#define BLACKWELL_MAX_LOG2_GOBS_Y       5

/* Error codes for sandbox-aware handling */
#define NV_ERR_SANDBOX_BLOCKED          (-EACCES)
#define NV_ERR_RESOURCE_BUSY            (-EAGAIN)

typedef struct {
    int nvctlFd;
    int nv0Fd;
    int drmFd;
    uint32_t clientObject;
    uint32_t deviceObject;
    uint32_t subdeviceObject;
    uint32_t driverMajorVersion;
    uint32_t driverMinorVersion;
    uint32_t gpu_id;
    uint32_t generic_page_kind;
    uint32_t page_kind_generation;
    uint32_t sector_layout;
    /* Blackwell and newer architecture fields */
    uint32_t gpu_arch;
    uint32_t supports_dmabuf_v2;
    bool isBlackwell;
    /* Blackwell-specific memory layout */
    uint32_t blackwell_alignment;
    uint32_t blackwell_page_size;
    bool supports_low_latency_decode;
} NVDriverContext;

typedef struct {
    int nvFd;
    int nvFd2;
    int drmFd;
    uint32_t width;
    uint32_t height;
    uint64_t mods;
    uint32_t memorySize;
    uint32_t offset;
    uint32_t pitch;
    uint32_t fourcc;
} NVDriverImage;

bool init_nvdriver(NVDriverContext *context, int drmFd);
bool free_nvdriver(NVDriverContext *context);
bool get_device_uuid(const NVDriverContext *context, uint8_t uuid[16]);
bool alloc_memory(const NVDriverContext *context, uint32_t size, int *fd);
bool alloc_image(NVDriverContext *context, uint32_t width, uint32_t height, uint8_t channels, uint8_t bytesPerChannel, uint32_t fourcc, NVDriverImage *image);

#endif
