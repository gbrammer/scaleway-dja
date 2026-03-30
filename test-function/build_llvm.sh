#!/bin/sh

# https://github.com/numba/llvmlite#compatibility
#
# llvmlite  LLVM
# --------  -----------------
# 0.45.0 -	20.x.x
# 0.44.0	15.x.x and 16.x.x

apk update
apk add --no-cache gcc musl-dev libstdc++ git build-base llvm16-dev clang16 cmake patchelf

pip install "setuptools<=71" --upgrade

# pip install numpy==1.26.4 --no-binary=:all: --upgrade --force

if [ ! -d "llvmlite-0.44.0" ]; then
    echo "Download llvmlite-0.44"
    wget https://files.pythonhosted.org/packages/89/6a/95a3d3610d5c75293d5dbbb2a76480d5d4eeba641557b69fe90af6c5b84e/llvmlite-0.44.0.tar.gz
    tar xzvf llvmlite-0.44.0.tar.gz
else
    echo "Found llvmlite-0.44"
fi

cd llvmlite-0.44.0

LLVM_CONFIG=$(which llvm16-config) python setup.py clean
LLVM_CONFIG=$(which llvm16-config) python setup.py build

WORKDIR=$(pwd)

cd build/lib.linux-x86_64-cpython-312/llvmlite/binding/

cp /usr/lib/libLLVM-16.so .
patchelf --replace-needed /usr/lib/libLLVM-16.so $PWD/libLLVM-16.so libllvmlite.so

ldd libllvmlite.so

cd $WORKDIR
LLVM_CONFIG=$(which llvm16-config) python setup.py install

cd ../

pip install numba==0.61.2 numpy==1.26.4

rm package_llvm/*

ls /usr/local/lib/python3.12/site-packages/

cp -R /usr/local/lib/python3.12/site-packages/* package_llvm/
