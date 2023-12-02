#pragma once

#if defined ARM64
#include "arm64/cache.h"
#elif defined AMD64
#include "amd64/cache.h"
#endif
