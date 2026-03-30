
# apk add llvm15-dev git

ln -s $PWD/package/llvmlite/binding/libLLVM-16.so /usr/lib/libLLVM-16.so
# ln -s /usr/lib/libLLVM-18.so /usr/lib/libLLVM-16.so

pip install awscli

python test_package.py --imports

python test_package.py
