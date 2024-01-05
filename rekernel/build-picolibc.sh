#!/bin/sh

mkdir -p build
cd build

export CFLAGS="-mgeneral-regs-only -D__BUFSIZ__=32768"

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
    -Doptimization=3 \
    -Dspecsdir=none \
    ../picolibc
ninja
ninja install
