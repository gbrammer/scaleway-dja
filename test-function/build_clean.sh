rm -rf package/*

# Run build_on_instance.sh on an amd64 instance
saws s3 cp s3://dja-cloud/function/package_linux_build.zip .
rm -rf package; unzip -a -o package_linux_build.zip
mv package package-linux-build

###### requirements from touched
saws s3 cp s3://dja-cloud/function/requirements.full.txt .

grep -v -e llvmlite -e numba -e numpy -e photutils -e opencv requirements.full.txt > requirements.full2.txt

###### build on docker
PYTHON_VERSION=3.12

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    /bin/sh build_llvm.sh

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    python test_llvm.py

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    /bin/sh build_astropy.sh

# Installs to package_numba
rm -rf package_numba; mkdir package_numba

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    /bin/sh build_in_docker.sh

######## (reset from backup during testing)
rm -rf package; cp -R package_numba package

######## Test imports
docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    --env-file ~/.aws/docker_environment.txt \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        python test_package.py --imports

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    --env-file ~/.aws/docker_environment.txt \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        /bin/sh test_package.sh

######## Trim package data

### Remove unused eazy templates
cd package
rm -rf eazy/data/eazy-photoz/.git

for templ in spline_templates PEGASE fsps_full BR07 uvisa_nmf EAZY_v1.1 magdis uvista_nmf CWW+KIN EAZY_v1.0; do
    echo "remove ${templ} eazy templates"
    find eazy/data/eazy-photoz/templates -name "${templ}*" -exec rm -rdf {} +
done
cd ../

### Remove unused eazy templates
rm package/msaexp/data/msa_sky/*csv
rm -rf  package/pysiaf/source_data/NIRSpec/delivery/*
rm -rf package/pysiaf/prd_data/HST/*
rm -rf package/pysiaf/prd_data/JWST/*

### tests
find package/pandas -name "*tests" -type d -exec rm -rdf {} +
find package/scipy -name "*tests" -type d -exec rm -rdf {} +
find package/numpy -name "*tests" -type d -exec rm -rdf {} +

for module in pandas scipy numpy grizli numba matplotlib sregion msaexp photutils tweakwcs sklearn regions mpl_toolkits llvmlite networkx spherical_geometry asdf_astropy asdf astroquery gwcs synphot poppy shapely drizzle numexpr greenlet wiimatch referencing unik eazy jwst pyvo stsci h5py; do
    find package/${module} -name "tests" -type d -exec rm -rdf {} +
done

find package -name "tests" -type d -exec du -shc {} + 
find package -name "*dist-info" -type d -exec du -shc {} + 
find package -name "__pycache__" -type d -exec du -shc {} + 

########################
##### Remove __pycache__, check which modules touched by test 
find package -name "__pycache__" -type d -exec rm -rf {} + 

# docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
#     --workdir /home/app/function \
#     --env-file ~/.aws/docker_environment.txt \
#     rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
#         python test_package.py --imports
#
# docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
#     --workdir /home/app/function \
#     --env-file ~/.aws/docker_environment.txt \
#     rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
#         python test_package.py
#
# python test_package.py --imports
# python test_package.py

rm gds-barruf* jw02* young_post_starburst.fits

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    --env-file ~/.aws/docker_environment.txt \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        /bin/sh test_package.sh

rm gds-barruf* jw02* young_post_starburst.fits

### Test done

modules=`find package -name "__pycache__" -type d -exec du -shc {} +  | sed "s/\// /g" | awk '{print $3}' | grep -v __pycache__ | uniq`

rm -rf package-touched
mkdir package-touched

for mod in $modules; do
    echo $mod
    cp -R package/${mod}* package-touched/
    #cp -R package/${mod}*dist-info package-touched/
    if [ -d package/${mod}.libs ]; then
        echo ${mod}.libs
        cp -R package/${mod}.libs* package-touched/
        # cp -R package/${mod}.libs*dist-info package-touched/
    fi
done

cp -R package/pillow*  package-touched/
cp package/*.py package-touched/
cp package/*.so package-touched/
cp -R package/logging_loki package-touched/
cp -R package/urllib3* package-touched/

# find package-touched -name "__pycache__" -type d -exec du -shc {} +
find package-touched -name "__pycache__" -type d -exec rm -rdf {} +

###### Run test with "package-touched"
mv package package-trim; mv package-touched package

rm gds-barruf* jw02* young_post_starburst.fits

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    --env-file ~/.aws/docker_environment.txt \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        /bin/sh test_package.sh

####### Keep only compiled files
find package/charset_normalizer -name "__pycache__" -type d -exec rm -rdf {} +
find package -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-312//'); cp $f $n; done;
find package -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
# remove .py versions of .pyc files
find package -type f -name '*.pyc' | sed "s/\.pyc/\.py/" | xargs rm -rf

du -shc *zip

rm package_msaexp.zip

zip -r -q package_msaexp.zip package -x "package/msaexp*" -x "package/scipy*" -x "package/numpy*" -x "package/astropy*" -x "package/matplotlib*" -x "package/sqlalch*" -x "package/psyco*" -x "package/request*" -x "package/boto*" -x "package/logging_loki*" -x "package/rfc3339*" -x "package/urllib3*" -x "package/idna*" -x "package/certifi*" -x "package/charset_normalizer*" -x "*__pycache__*"

saws s3 cp package_msaexp.zip s3://dja-cloud/function/ --acl public-read

du -shc *zip

rm package_alpine.zip

zip -r -q package_alpine.zip package handlers -i "handlers/*.py" -i "package/msaexp*" -i "package/scipy*" -i "package/numpy*" -i "package/astropy*" -i "package/matplotlib*" -i "package/sqlalch*" -i "package/psyco*" -i "package/request*" -i "package/boto*" -i "package/logging_loki*" -i "package/rfc3339*" -i "package/urllib3*" -i "package/idna*" -i "package/certifi*" -i "package/charset_normalizer*" -x "*__pycache__*"

# zip -r -q package_alpine.zip package handlers -x "package/msaexp*" -x "package/llvmlite*" -x "package/numba*" -x "package/jwst*" -x "package/crds*" -x "package/eazy*" -x "package/grizli*" -x "*__pycache__*"

du -shc *zip

rm -rf tmp_alpine; unzip -q -o package_alpine.zip -d tmp_alpine; du -shc tmp_alpine

rm -rf tmp_msaexp; unzip -q -o package_msaexp.zip -d tmp_msaexp; du -shc tmp_msaexp


# Test handler
PYTHON_VERSION=3.12

rm -rf tmp_alpine; unzip -q -o package_alpine.zip -d tmp_alpine; du -shc tmp_alpine

pip install python_logging_loki requests urllib3 --target tmp_alpine/package/ --upgrade --force
pip install boto3 --target tmp_alpine/package/ --upgrade --force

cp test_handler.py tmp_alpine/
cp handlers/handle.py tmp_alpine/handlers/

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd)/tmp_alpine:/home/app/function \
    --workdir /home/app/function \
    --env-file ~/.aws/docker_environment.txt \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
        python test_handler.py

