#pragma once

#include <string.h>

static inline void inv_dcache(char* start, size_t len) {}
static inline void clean_dcache(char* start, size_t len) {}
static inline void cinv_dcache(char* start, size_t len) {}
