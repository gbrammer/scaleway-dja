#!/bin/bash

PYTHON_VERSION=3.12 # or 3.7, 3.8, ...

# rm -rf package/*

docker run --platform linux/amd64 --rm -v $(pwd):/home/app/function --workdir /home/app/function rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:$PYTHON_VERSION pip install -r requirements.txt --target ./package

rm -rf `find package/ | grep __pycache__` functions.zip

zip -r functions.zip handlers/ package/