#!/bin/sh

mkdir -p build
cd build

export CFLAGS="-mgeneral-regs-only"

meson \
    -Dtls-model=local-exec \
    -Dmultilib=false \
    -Dpicolib=false \
    -Dpicocrt=false \
    -Dposix-console=true \
    -Dnewlib-global-atexit=true \
    -Dprefix=$PWD/install \
    -Dincludedir=include \
    -Dlibdir=lib \
    -Dformat-default=long-long \
    -Dthread-local-storage=false \
    -Datomic-ungetc=false \
    -Dspecsdir=none \
    ../picolibc
ninja
ninja install
