#ifndef CHROME_DETECT_H
#define CHROME_DETECT_H

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>

static inline bool is_chrome_detect(void) {
    if (getenv("FORCENVDEC")) return true;
    char path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
    if (len != -1) {
        path[len] = '\0';
        if (strstr(path, "chrome") != NULL || strstr(path, "chromium") != NULL || strstr(path, "thorium") != NULL) {
            return true;
        }
    }
    return false;
}

#endif
