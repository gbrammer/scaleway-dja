apt-get update
apt-get install git -y
apt-get install gcc -y
apt-get install curl procps -y

export CRDS_PATH=/GrizliImaging/crds_cache
export CRDS_SERVER_URL=https://jwst-crds.stsci.edu
export GRIZLI=/GrizliImaging/GRIZLI
export iref=/GrizliImaging/GRIZLI/iref
export jref=/GrizliImaging/GRIZLI/jref

mkdir /GrizliImaging

# WORKDIR /GrizliImaging
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda -c
rm Miniconda3-latest-Linux-x86_64.sh

source .bashrc

conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

conda create -n py312 "python=3.12" -y
conda activate py312

pip install pip --upgrade

# Install Flask
pip install flask gunicorn

pip install grizli[aws,jwst] msaexp
pip install git+https://github.com/karllark/dust_attenuation.git
python -c "import eazy; eazy.fetch_eazy_photoz()"

# unix utilities (procps provides "top")

pip install python-logging-loki

# Install from repo
pip install grizli[aws,jwst] --upgrade
pip install git+https://github.com/gbrammer/msaexp.git --upgrade

pip cache purge
conda clean -a -y

mkdir /GrizliImaging/GRIZLI
mkdir /GrizliImaging/GRIZLI/iref
mkdir /GrizliImaging/GRIZLI/jref
mkdir /GrizliImaging/GRIZLI/CONF
mkdir /GrizliImaging/GRIZLI/templates

### CONFIG files for GRIZLI imaging

python -c "import grizli.utils; grizli.utils.fetch_config_files(get_acs=False, get_jwst=True)"
python -c "import grizli.utils; grizli.utils.symlink_templates(force=True)"

# python -c "import grizli.utils; grizli.utils.fetch_nircam_skyflats()"
# python -c "import grizli.utils; grizli.utils.fetch_nircam_wisp_templates()"

python scaleway-dja/docker-instance/ProcessingApp/initialize_crds.py

python $HOME/scaleway-dja/docker-instance/ProcessingApp/app.py --msa --fixed

# COPY run_msa_tests.py .

# test examples to fetch CRDS environment
# python app.py --ifu --fixed
# python app.py --msa --fixed
#
# rm /GrizliImaging/crds_cache/references/jwst/nirspec/*fits
# rm /GrizliImaging/*lock* /GrizliImaging/*nirspec*

# the app with Gunicorn
# CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 app:app

CMD ["python3", "./app.py"]
