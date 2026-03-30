apk update
apk add --no-cache gcc musl-dev libstdc++ git

which gcc git
# pip install pip --upgrade

apk add build-base llvm16-dev clang16 cmake

ls /usr/bin/llvm16-config

which llvm16-config

pip install "setuptools<=71" --upgrade

# pip install numpy==1.26.4 --no-binary=:all: --upgrade --force

wget https://files.pythonhosted.org/packages/89/6a/95a3d3610d5c75293d5dbbb2a76480d5d4eeba641557b69fe90af6c5b84e/llvmlite-0.44.0.tar.gz

tar xzvf llvmlite-0.44.0.tar.gz
cd llvmlite-0.44.0

LLVM_CONFIG=$(which llvm16-config) python setup.py build
LLVM_CONFIG=$(which llvm16-config) python setup.py install

# LLVM_CONFIG=$(which llvm16-config) pip install numpy==1.26.4 --no-binary=:all: --target ./package2 

cd ../
rm -rf llvmlite-0.44*

LLVM_CONFIG=$(which llvm16-config) pip install numba==0.61.2 numpy==1.26.4 --no-deps

wget https://files.pythonhosted.org/packages/10/b6/2ecd1ddebf269aa78103959a99ebb2c2ca9070f392cf10ac767fc4176b2a/photutils-1.12.0.tar.gz
tar xzvf photutils-1.12.0.tar.gz
cd photutils-1.12.0
pip install . 
cd ../
rm -rf photutils-1.12.0*

# pip install grizli[aws] msaexp python-logging-loki pandas
# pip install git+https://github.com/karllark/dust_attenuation.git

pip install -r requirements.full2.txt --no-deps

# apk add geos geos-dev
# pip install shapely --no-binary shapely
#
# pip install sqlalchemy --no-binary sqlalchemy

cp -R /usr/local/lib/python3.12/site-packages/* package_numba/
cp /usr/lib/libLLVM-16.so package_numba/llvmlite/binding/

# pip install -r requirements.touched.txt --target ./package2 --no-deps
