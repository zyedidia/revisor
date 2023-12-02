#!/bin/sh

mkdir -p build
cd build

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
    -Dthread-local-storage=false \
	-Dspecsdir=none \
    ../picolibc
ninja
ninja install
