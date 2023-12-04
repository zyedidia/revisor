#pragma once

#if defined ARM64
#include "arch/arm64/cache.h"
#elif defined AMD64
#include "arch/amd64/cache.h"
#endif
