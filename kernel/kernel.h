#pragma once

#include "x86-64.h"

// Return the number of elements in an array
#define arraysize(array)  (sizeof(array) / sizeof(array[0]))

void sbrk_init();
