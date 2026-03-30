target_dir=package_astropy

rm -rf ${target_dir}

pip install numpy==1.26.4 python_logging_loki astropy boto3 sqlalchemy psycopg2-binary pandas  --target ${target_dir}

pip install msaexp grizli unik sregion --target ${target_dir} --no-deps --no-cache-dir

rm ${target_dir}/msaexp/data/msa_sky/*csv

du -shc ${target_dir}

find ${target_dir}/pandas -name "*tests" -type d -exec rm -rdf {} +
find ${target_dir}/scipy -name "*tests" -type d -exec rm -rdf {} +
find ${target_dir}/numpy -name "*tests" -type d -exec rm -rdf {} +

for module in pandas scipy numpy grizli numba matplotlib sregion msaexp photutils tweakwcs sklearn regions mpl_toolkits llvmlite networkx spherical_geometry asdf_astropy asdf astroquery gwcs synphot poppy shapely drizzle numexpr greenlet wiimatch referencing unik eazy jwst pyvo stsci h5py; do
    find ${target_dir}/${module} -name "tests" -type d -exec rm -rdf {} +
done

echo "tests"; du -shc ${target_dir}

find ${target_dir} -name "__pycache__" -type d -exec rm -rf {} + 

echo "__pycache__"; du -shc ${target_dir}

# find ${target_dir} -name "*.so" -type f -exec strip -s {} +
#
# echo "strip"; du -shc ${target_dir}
#
# strip --help