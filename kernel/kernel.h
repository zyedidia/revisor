#pragma once

#include "x86-64.h"

// Return the number of elements in an array
#define arraysize(array)  (sizeof(array) / sizeof(array[0]))

void exception_return(x86_64_registers* regs) __attribute__((noreturn));

void sbrk_init();
