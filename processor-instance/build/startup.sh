# apt-get update
# apt-get install git -y
# apt-get install gcc -y
# apt-get install curl procps -y

export CRDS_PATH=/GrizliImaging/crds_cache
export CRDS_SERVER_URL=https://jwst-crds.stsci.edu
export GRIZLI=/GrizliImaging/GRIZLI
export iref=/GrizliImaging/GRIZLI/iref
export jref=/GrizliImaging/GRIZLI/jref

# initialize block storage
# mkfs.ext4 /dev/sdb
# mkdir /mnt/telescopes
# mount -o defaults /dev/sdb /mnt/telescopes

mkdir /GrizliImaging

# WORKDIR /GrizliImaging
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda -c
rm Miniconda3-latest-Linux-x86_64.sh

# source .bashrc
__conda_setup="$('/root/miniconda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"

# This stuff in .bashrc from conda init
if [ $? -eq 0 ]; then
    echo "eval conda_setup"
    eval "$__conda_setup"
else
    if [ -f "/root/miniconda/etc/profile.d/conda.sh" ]; then
        echo "run /root/miniconda/etc/profile.d/conda.sh"
        . "/root/miniconda/etc/profile.d/conda.sh"
    else
        echo "export PATH=\"/root/miniconda/bin:$PATH\""
        export PATH="/root/miniconda/bin:$PATH"
    fi
fi

# startup in .bashrc
cat <<EOF >> /root/.bashrc

conda activate py312

# GRIZLI environment
export CRDS_PATH=/GrizliImaging/crds_cache
export CRDS_SERVER_URL=https://jwst-crds.stsci.edu
export GRIZLI=/GrizliImaging/GRIZLI
export iref=/GrizliImaging/GRIZLI/iref
export jref=/GrizliImaging/GRIZLI/jref
EOF

mkdir /root/.aws
cat <<EOF > /root/.aws/config
[default]
output = text
region = us-east-1

[profile aws]
output = text
region = us-east-1

[profile scw]
region = fr-par
output = text
services = scw-fr-par

[services scw-fr-par]
s3 =
  endpoint_url = https://s3.fr-par.scw.cloud
  max_concurrent_requests = 100
  max_queue_size = 1000
  multipart_threshold = 50 MB
s3api =
  endpoint_url = https://s3.fr-par.scw.cloud
EOF

cat <<EOF >> /root/.bashrc

alias saws="aws --profile scw"
EOF

##################
# Manually add credentials environment vars
##################

conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

conda create -n py312 "python=3.12" -y
conda activate py312

pip install pip --upgrade

# Install Flask
pip install flask gunicorn

pip install grizli[aws,jwst,hst] msaexp
pip install git+https://github.com/karllark/dust_attenuation.git
python -c "import eazy; eazy.fetch_eazy_photoz()"

# unix utilities (procps provides "top")

pip install python-logging-loki

# Install from repo
pip install grizli[aws,hst,jwst] --upgrade
pip install git+https://github.com/gbrammer/msaexp.git --upgrade

conda install -c conda-forge hstcal -y

# Jupyter lab
# https://docs.aws.amazon.com/dlami/latest/devguide/setup-jupyter-secure.html
mkdir ssl
cd ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout mykey.key -out mycert.pem
cd ../

pip install jupyter
jupyter notebook password

cat <<EOF >> /root/.bashrc
alias launch_labserver='jupyter lab --certfile=~/ssl/mycert.pem --keyfile ~/ssl/mykey.key --allow-root'
EOF

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

git clone "https://github.com/gbrammer/scaleway-dja.git" /root/scaleway-dja

python scaleway-dja/processor-instance/app/initialize_crds.py

# scw cli
curl -s https://raw.githubusercontent.com/scaleway/scaleway-cli/master/scripts/get.sh | sh

# python3 $HOME/scaleway-dja/processor-instance/app/app.py --msa --fixed
# python3 $HOME/scaleway-dja/processor-instance/app/app.py --ifu --fixed
# python3 $HOME/scaleway-dja/processor-instance/app/app.py --assoc --fixed

# COPY run_msa_tests.py .

# test examples to fetch CRDS environment
# python app.py --ifu --fixed
# python app.py --msa --fixed
#
# rm /GrizliImaging/crds_cache/references/jwst/nirspec/*fits
# rm /GrizliImaging/*lock* /GrizliImaging/*nirspec*

# the app with Gunicorn
# CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 app:app

# CMD ["python3", "./app.py"]
