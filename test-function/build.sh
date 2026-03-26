#!/bin/bash

PYTHON_VERSION=3.12 # or 3.7, 3.8, ...

rm -rf package/*

# docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function --workdir /home/app/function rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION pip install -r requirements.txt --target ./package

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install -r requirements.redshift.txt --target ./package \
        --no-deps

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install msaexp --target ./package --no-deps

docker run --cpus 4 --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    pip install python-logging-loki --target ./package

docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function \
    --workdir /home/app/function \
    rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
    find package -name "*.so" -exec strip -SXxs {} +

# docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function \
#     --workdir /home/app/function \
#     rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION \
#         python -c "import os; import sys; sys.path.append(os.path.join(os.getcwd(), 'package')); import eazy; eazy.fetch_eazy_photoz()"

# eazy templates
gg25
virtualenv venv
conda deactivate
conda deactivate
source venv/bin/activate

unset EAZYCODE

cd package

python -c "import eazy; eazy.fetch_eazy_photoz()"
rm -rf eazy/data/eazy-photoz/.git

for templ in spline_templates PEGASE fsps_full BR07 uvisa_nmf EAZY_v1.1 magdis uvista_nmf CWW+KIN EAZY_v1.0; do
    echo "remove ${templ} eazy templates"
    find eazy/data/eazy-photoz/templates -name "${templ}*" -d -exec rm -rdf {} +
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

mv package package-backup-full

# https://s3.amazonaws.com/grizli-v2/scratch/function_package.zip

# rm -rf package-backup-full
# cp -R package package-backup-full

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