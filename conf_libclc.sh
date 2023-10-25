#!/bin/bash

prefix=${PREFIX:-/opt/gbelgurr-amd/llvm-project}

if test x$1 = x32; then
    arch=llvm-i386

    cflags="-m32"
    cxxflags="-m32"
    # bindgen doesn't work for 32 bit builds yet
else
    arch=llvm
fi

rm -rf buildclc$1

set -e

mkdir buildclc$1
cd buildclc$1

cmake ../libclc -G Ninja -DCMAKE_INSTALL_PREFIX=$prefix/$arch -DLIBCLC_TARGETS_TO_BUILD=all \
	-DLLVM_DIR=$prefix/$arch/lib/cmake/llvm -DCMAKE_C_FLAGS=$cflags -DCMAKE_CXX_FLAGS=$cxxflags

cd ..

