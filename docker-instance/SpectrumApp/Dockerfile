# Use the official Python slim image
FROM python:3.12-slim

RUN apt-get update
RUN apt-get install git -y
RUN apt-get install gcc -y

ENV CRDS_PATH=/GrizliImaging/crds_cache
ENV CRDS_SERVER_URL=https://jwst-crds.stsci.edu

RUN mkdir /GrizliImaging

WORKDIR /GrizliImaging

RUN pip install pip --upgrade

# Install Flask
RUN pip install flask gunicorn

RUN date # 2026-03-02.1

RUN pip install grizli[aws,jwst] msaexp
RUN pip install git+https://github.com/karllark/dust_attenuation.git
RUN python -c "import eazy; eazy.fetch_eazy_photoz()"

# unix utilities (procps provides "top")
RUN apt install curl procps -y

RUN pip install python-logging-loki

RUN pip install grizli --upgrade
RUN pip install msaexp --upgrade

RUN date # 2026-03-03.7

RUN pip install grizli[aws,jwst] --upgrade

RUN date # 2026-03-12.1
RUN pip install git+https://github.com/gbrammer/msaexp.git --upgrade

RUN pip cache purge

RUN mkdir /GrizliImaging/GRIZLI
RUN mkdir /GrizliImaging/GRIZLI/iref
RUN mkdir /GrizliImaging/GRIZLI/jref
RUN mkdir /GrizliImaging/GRIZLI/CONF
RUN mkdir /GrizliImaging/GRIZLI/templates

ENV GRIZLI=/GrizliImaging/GRIZLI
ENV iref=/GrizliImaging/GRIZLI/iref
ENV jref=/GrizliImaging/GRIZLI/jref

### CONFIG files for GRIZLI imaging

# RUN python -c "import grizli.utils; grizli.utils.fetch_config_files(get_acs=False, get_jwst=True)"
# RUN python -c "import grizli.utils; grizli.utils.symlink_templates(force=True)"

# RUN python -c "import grizli.utils; grizli.utils.fetch_nircam_skyflats()"
# RUN python -c "import grizli.utils; grizli.utils.fetch_nircam_wisp_templates()"

ENV PORT=8080
EXPOSE 8080

COPY initialize_crds.py .
RUN python initialize_crds.py

COPY app.py .

# RUN python -c "import app; app.test_handler()"

# COPY run_msa_tests.py .

# Run test examples to fetch CRDS environment
# RUN python app.py --ifu --fixed
# RUN python app.py --msa --fixed
#
# RUN rm /GrizliImaging/crds_cache/references/jwst/nirspec/*fits
# RUN rm /GrizliImaging/*lock* /GrizliImaging/*nirspec*

# Run the app with Gunicorn
# CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 app:app

CMD ["python3", "./app.py"]
