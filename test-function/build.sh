#!/bin/bash

PYTHON_VERSION=3.12 # or 3.7, 3.8, ...

rm -rf package/*

# Run build_on_instance.sh on an amd64 instance
saws s3 cp s3://dja-cloud/function/package_linux_build.zip .
rm -rf package; unzip -a -o package_linux_build.zip
mv package package-linux-build

###### requirements from touched
saws s3 cp s3://dja-cloud/function/requirements.full.txt .

grep -v -e llvmlite -e numba -e numpy -e photutils requirements.full.txt > requirements.full2.txt

keeps=`ls package/ | grep -v dist-info | sed "s/\.py//g" | uniq`
rm requirements.touched.txt
for keep in $keeps; do
    grep $keep requirements.full.txt >> requirements.touched.txt
done
cat requirements.touched.txt | uniq > tmp.txt
mv tmp.txt requirements.touched.txt
echo "attr==0.3.2" >> requirements.touched.txt
rm -rf package/

perl -pi -e "s/\/root\/scaleway-dja\/test-function\/venv\/bin\/python/\/usr\/bin\/env python/" package/bin/*

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        python test_package.py --pathonly

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        python test_package.py --import

##########
# saws s3 cp s3://dja-cloud/function/requirements.touched.txt .

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    /bin/sh build_in_docker.sh

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install awscli --target ./package --no-deps

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install numpy==1.26.4 --target ./package

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    apk add --no-cache gcc musl-dev libstdc++ && pip install numpy==1.26.4 numba --target ./package --upgrade

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        python test_package.py --imports

# Install most dependencies
docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install -r requirements.redshift.txt --target ./package \
        --no-deps


# llvmlite
# docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
#     --workdir /home/app/function \
#     rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
#         /bin/sh

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install numba numpy==1.26.4 --target ./package --upgrade --no-deps

# Install msaexp
docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install msaexp --target ./package --upgrade --no-deps

# Install logging-loki
docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install python-logging-loki --target ./package --upgrade

# Strip compiled binaries
docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    find package -name "*.so" -exec strip -SXxs {} +

# eazy templates

gg25
virtualenv venv
conda deactivate
conda deactivate
source venv/bin/activate

unset EAZYCODE

cd package

# Download eazy templates and filters
python -c "import eazy; eazy.fetch_eazy_photoz()"
rm -rf eazy/data/eazy-photoz/.git

# Remove unused templates
for templ in spline_templates PEGASE fsps_full BR07 uvisa_nmf EAZY_v1.1 magdis uvista_nmf CWW+KIN EAZY_v1.0; do
    echo "remove ${templ} eazy templates"
    find eazy/data/eazy-photoz/templates -name "${templ}*" -exec rm -rdf {} +
done
cd ../

# streamline package distribution
find package -name "*-info" -type d -exec rm -rdf {} +
find package -name "__pycache__" -type d -exec rm -rdf {} +

find package/pandas -name "*tests" -type d -exec rm -rdf {} +
find package/scipy -name "*tests" -type d -exec rm -rdf {} +
find package/numpy -name "*tests" -type d -exec rm -rdf {} +
for module in pandas scipy numpy grizli numba matplotlib sregion msaexp; do
    find package/${module} -name "*tests" -type d -exec rm -rdf {} +
done

find package -name "*tests" -type d -exec du -shc {} + 

# full package distribution
mv package package-backup-full

# https://s3.amazonaws.com/grizli-v2/scratch/function_package.zip

# rm -rf package-backup-full
# cp -R package package-backup-full

# Split package into pieces, one zip file to upload with the app
# and a separate zip file with additional dependencies that don't fit
rm -rf package-backup package package-app
cp -R package-backup-full package-backup

rm package-backup/msaexp/data/msa_sky/*csv

mkdir package

mv package-backup/*.py package/

for mod in numpy requests certifi charset_normalizer idna urllib3 logging_loki; do
    mv package-backup/${mod}* package/
done

for mod in astropy botocore boto3 yaml _yaml PIL erfa dateutil cycler contourpy packaging; do
    mv package-backup/${mod}* package/
done

for mod in mpl_toolkits shapely kiwisolver numba pillow psycopg2 sqlalchemy; do
    mv package-backup/${mod}* package/
done

for mod in unik tqdm sregion share s3transfer pyparsing jmespath; do
    mv package-backup/${mod}* package/
done

for mod in bin fontTools msaexp; do
    mv package-backup/${mod}* package/
done

# above gets to 96M zipped, 207 unzipped

# for mod in grizli msaexp; do
#     mv package-backup/${mod}* package/
# done

rm handlers.zip
zip -r -q handlers.zip handlers/ package/
du -shc handlers.zip package package-backup

zip -r -q ../package.zip ./

tfpa

mv package package-app
mv package-backup package

zip -r -q function_package.zip package/
du -shc *.zip package package-app

aws s3 cp function_package.zip s3://grizli-v2/scratch/ --acl public-read
saws s3 cp function_package.zip s3://dja-cloud/function/ --acl public-read

mv package package-suppl
mv package-app package

# Repackage with just updates to handlers
rm handlers.zip
zip -q -r handlers.zip handlers/ package/
du -shc handlers.zip package package-suppl

tfpa


# reset for pip updates above
rm -rf package package-suppl package-app
mv package-backup-full package


curl -H "X-Auth-Token: $(terraform output -raw secret_key)"     "https://$(terraform output -raw function_endpoint)/"

curl -H "X-Auth-Token: $(terraform output -raw secret_key)"     "https://$(terraform output -raw function_endpoint)/?param=value"

curl -H "X-Auth-Token: $(terraform output -raw secret_key)"     "https://$(terraform output -raw function_endpoint)/?zfile=gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits"

curl -H "X-Auth-Token: $(terraform output -raw secret_key)"     "https://$(terraform output -raw function_endpoint)/?zfile=gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits&log_level=20"


## Test msaexp redshift fit
# docker run --platform linux/amd64 --env-file ~/.aws/docker_environment.txt --rm -v $(pwd):/home/app/function     --workdir /home/app/function     rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION     python handlers/handle.py

# docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function \
#     --workdir /home/app/function \
#     rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
#     python handlers/handle.py

# docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function --workdir /home/app/function rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION ls /usr/local/lib/python3.12/lib-dynload

# docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function --workdir /home/app/function rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION yum install libopenblas-dev -y


## On amd64 instance

# python 3.10
apt-get install python3 python3-pip virtualenv -y

virtualenv venv
source venv/bin/activate

pip install astropy boto3 botocore numpy==1.26.4 matplotlib numba matplotlib scipy sregion unik tqdm python-logging-loki psycopg2-binary sqlalchemy pandas shapely pyyaml

pip install grizli --no-deps
pip install msaexp --no-deps
pip install eazy --no-deps

pip freeze > requirements.redshift.310.txt

# python -c "import eazy; eazy.fetch_eazy_photoz()"

pip install -r requirements.redshift.310.txt --target ./xpackage --no-deps

# pip install -r requirements.redshift.310.txt --target ./package --no-deps

pip install llvmlite==0.46.0 numba==0.64.0 numpy==1.26.4 --target ./package --no-binary=:all: --compile -Ccompile-option="-g0" -Ccompile-option="-Wl,-strip-all"

pip install llvmlite==0.46.0 numba==0.64.0 numpy==1.26.4 --target ./package --no-binary=:all: --compile -Ccompile-option="-g0" -Ccompile-option="-Wl,-strip-all"

apt-get install llvm llvm-dev -y
0.43
LLVM_CONFIG=/usr/bin/llvm-config-14 pip install llvmlite==0.43 --no-binary=:all: --target ./package --upgrade

pip install llvmlite==0.46.0 numba==0.64.0 --no-binary=:all: --target ./package --upgrade

pip install numpy==1.26.4 --target ./package --no-binary=:all: --compile -Ccompile-option="-g0" -Ccompile-option="-Wl,-strip-all"

apt-get install gcc g++ -y
apt-get install gfortran libopenblas-dev liblapack-dev pkg-config -y
apt-get install cmake make libedit-dev -y
apt-get install zlib1g-dev -y
apt-get install zstd-dev -y

conda install -c numba llvmdev==20.1.8 -y

LLVMLITE_SHARED=1 python setup.py build
python setup.py install --prefix ../package
mv ../package/lib/python3.12/site-packages/llvmlite* ../package/
rm -rf ../package/lib

pip install numba==0.64.0 --no-binary=:all: --target ./package --upgrade --no-deps

pip install psycopg2-binary --target ./package

pip install sqlalchemy --no-binary=:all: --target ./package --upgrade

pip install pandas --no-binary=:all: --target ./package --upgrade

find package -name "*.so" -exec strip -SXxs {} +
