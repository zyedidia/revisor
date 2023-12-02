#pragma once

#include <string.h>

static inline void inv_dcache(char* start, size_t len) {
    for (size_t i = 0; i < len; i++) {
        asm volatile ("dc ivac, %0" :: "r"(start + i));
    }
}

static inline void clean_dcache(char* start, size_t len) {
    for (size_t i = 0; i < len; i++) {
        asm volatile ("dc cvac, %0" :: "r"(start + i));
    }
}

static inline void cinv_dcache(char* start, size_t len) {
    for (size_t i = 0; i < len; i++) {
        asm volatile ("dc civac, %0" :: "r"(start + i));
    }
}
