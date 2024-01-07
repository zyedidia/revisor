#!/bin/sh

mkdir -p build
cd build

export CFLAGS="-mgeneral-regs-only -DGENERAL_REGS_ONLY -DBUFSIZ=8192"

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
    -Dfast-bufio=true \
    ../picolibc
ninja
ninja install
