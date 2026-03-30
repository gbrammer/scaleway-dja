
cat <<EOF > /usr/local/bin/dubig
#!/bin/bash

if [ \$# -eq 0 ]; then 
    files=\`ls\`
else
    files=\$@
fi

du -sc $files | sort -nr | awk '
     BEGIN {
        split("KB,MB,GB,TB", Units, ",");
     }
     {
        u = 1;
        while (\$1 >= 1024) {
           \$1 = \$1 / 1024;
           u += 1
        }
        \$1 = sprintf("%5.1f %s", \$1/2, Units[u]);
        print \$0;
     }' | grep -v KB
EOF
chmod +x /usr/local/bin/dubig

cd /root/scaleway-dja/test-function

pip install virtualenv
conda deactivate

conda activate py312

virtualenv venv
virtualenv venv-clean

conda deactivate
conda deactivate

source venv/bin/activate

######## Install base environment with dependencies
pip install grizli[aws] msaexp python-logging-loki pandas
pip install git+https://github.com/karllark/dust_attenuation.git

python -c "import eazy; eazy.fetch_eazy_photoz()"

######## Test in venv
python test_package.py
rm gds-barruf* jw02* young_post_starburst.fits

######## Full environment
pip freeze > requirements.full.txt

######## Install into ./package
pip install -r requirements.full.txt --target ./package --no-deps

######## make a backup
cp -R package package-full

######## (reset from backup during testing)
rm -rf package; cp -R package-full package

######## Run with just package env
source venv-clean/bin/activate

python test_package.py --imports

######## Trim package data
# find package -name "*.so" -exec strip -Sx {} +

dubig `find package -name "*.so*" -type f`

for module in llvmlite cv2; do
    find package/${module} -name "*.so*" -type f -exec strip -Sx {} + 
done

#package/llvmlite/binding/libllvmlite.so

### Remove unused eazy templates
cd package
rm -rf eazy/data/eazy-photoz/.git

for templ in spline_templates PEGASE fsps_full BR07 uvisa_nmf EAZY_v1.1 magdis uvista_nmf CWW+KIN EAZY_v1.0; do
    echo "remove ${templ} eazy templates"
    find eazy/data/eazy-photoz/templates -name "${templ}*" -exec rm -rdf {} +
done
cd ../

rm package/msaexp/data/msa_sky/*csv
rm -rf  package/pysiaf/source_data/NIRSpec/delivery/*
rm -rf package/pysiaf/prd_data/HST/*
rm -rf package/pysiaf/prd_data/JWST/*

# streamline
# find package -name "*-info" -type d -exec rm -rdf {} +
# find package -name "__pycache__" -type d -exec rm -rdf {} +

find package/pandas -name "*tests" -type d -exec rm -rdf {} +
find package/scipy -name "*tests" -type d -exec rm -rdf {} +
find package/numpy -name "*tests" -type d -exec rm -rdf {} +

for module in pandas scipy numpy grizli numba matplotlib sregion msaexp photutils tweakwcs sklearn regions mpl_toolkits llvmlite networkx spherical_geometry asdf_astropy asdf astroquery gwcs synphot poppy shapely drizzle numexpr greenlet wiimatch referencing unik eazy jwst pyvo stsci h5py; do
    find package/${module} -name "tests" -type d -exec rm -rdf {} +
done

find package -name "tests" -type d -exec du -shc {} + 
find package -name "*dist-info" -type d -exec du -shc {} + 
find package -name "__pycache__" -type d -exec du -shc {} + 

# find package -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-312//'); cp $f $n; done;
# find package -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
# find package -type f -a -name '*.py' -print0 | xargs -0 rm -f

########################
##### Remove __pycache__, check which modules touched by test 
find package -name "__pycache__" -type d -exec rm -rf {} + 

python test_package.py --imports

python test_package.py
rm gds-barruf* jw02* young_post_starburst.fits

find package -name "__pycache__" -type d -exec du -shc {} + 

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

for mod in pkg_resources pillow imageio typing_extensions charset_normalizer; do
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
cp -R package/bin package-touched/
cp -R package/awscli* package-touched/

###### requirements from touched
keeps=`ls package-touched/ | grep -v dist-info | sed "s/\.py//g" | uniq`
rm requirements.touched.txt
for keep in $keeps; do
    grep $keep requirements.full.txt >> requirements.touched.txt
done
cat requirements.touched.txt | uniq > tmp.txt
mv tmp.txt requirements.touched.txt
echo "attr==0.3.2" >> requirements.touched.txt

find package-touched -name "__pycache__" -type d -exec rm -rdf {} +
find package-touched/astropy/[a-su-z]* -name "tests" -type d -exec rm -rf {} + 
perl -pi -e "s/\/root\/scaleway-dja\/test-function\/venv\/bin\/python/\/usr\/bin\/env python/" package-touched/bin/*

###### Run test with "package-touched"
mv package package-trim; mv package-touched package

# find package -name "__pycache__" -type d -exec du -shc {} +
find package -name "__pycache__" -type d -exec rm -rdf {} +

python test_package.py --imports

python test_package.py
rm gds-barruf* jw02* young_post_starburst.fits

apt-get update
apt-get install zip -y

find package -name "__pycache__" -type d -exec du -shc {} +

find package -name "__pycache__" -type d -exec rm -rdf {} +

zip -r -q package_linux_build.zip package/
saws s3 cp package_linux_build.zip s3://dja-cloud/function/ --acl public-read
saws s3 cp requirements.full.txt s3://dja-cloud/function/ --acl public-read
saws s3 cp requirements.touched.txt s3://dja-cloud/function/ --acl public-read

#### run test and keep only compiled C code
deactivate; source venv-clean/bin/activate
python test_package.py
rm gds-barruf* jw02* young_post_starburst.fits

find package/charset_normalizer -name "__pycache__" -type d -exec rm -rdf {} +
find package -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-312//'); cp $f $n; done;
find package -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
### find package -type f -a -name '*.py' -print0 | xargs -0 rm -f
# remove .py versions of .pyc files
find package -type f -name '*.pyc' | sed "s/\.pyc/\.py/" | xargs rm -rf

mv package package-touched; mv package-trim package

