
# App for spectrum combination and redshift fits

## Start an instance for building the Dockerfile

```bash
cd ${SCWREPO}/docker-instance/terraform

terraform init

terraform plan

terraform apply # -auto-approve
```
## Connect to the instance

```bash
./connect_to_instance.sh

##### Build the docker image

cd /root/scaleway-dja/docker-instance/SpectrumApp/

container_namespace=ns-dja-app-containers

##### Create the namespace (on local machine with scw installed)
if test `scw registry namespace list name=${container_namespace} | wc -l` -lt "2"; then
    echo "scw registry namespace create name=${container_namespace} is-public=false region=fr-par"
else
    echo "Found registry namespace: ${container_namespace}"
fi
#####

docker login rg.fr-par.scw.cloud/${container_namespace} -u nologin # enter SCW_SECRET_KEY

app_tag=dja-msaexp-spectra

git pull

docker build -t ${app_tag} .

docker run -it --env-file /root/docker_environment.txt ${app_tag}

curl -X POST "http://172.17.0.2:8080/?arg1=value1" -d '{"key": 1.0, "key2": 2, "key3": "a_string"}' -H "Content-Type: application/json"

curl -X POST "http://172.17.0.2:8080/?arg1=value1" -d '{
  "runmode": "msa-redshift",
  "zfile": "gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits"
}' -H "Content-Type: application/json"


##### Test it
test="""
    docker run -it --env-file /root/docker_environment.txt --entrypoint /bin/bash ${app_tag}

    python -c "import app; result = app.test_handler_combine()"
    python -c "import app; result = app.test_handler_redshift()"

"""

##### Tag and push to container repository
docker tag ${app_tag}:latest rg.fr-par.scw.cloud/${container_namespace}/${app_tag}:latest

docker push rg.fr-par.scw.cloud/${container_namespace}/${app_tag}:latest

```

## Tear down docker instance

```bash
terraform destroy
```

## Test the container

```bash

curl -X GET "$(terraform output -raw container_endpoint)" -H "X-Auth-Token: $(terraform output -raw secret_key)"

#### One way to launch the function is with URL args
args="runmode=msa-redshift&zfile=gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits"

curl -X POST "https://$(terraform output -raw container_endpoint)/?${args}&log_level=20" -H "X-Auth-Token: $(terraform output -raw secret_key)"

#### ``POST --data`` doesn't seem to be parsed correctly?
#### - actually may be OK depending on quote chars
post_data='{"skey": "value", "ikey": 2, "fkey": 2.0}'

curl -X POST "$(terraform output -raw container_endpoint)/" -H "X-Auth-Token: $(terraform output -raw secret_key)" -H "Content-type: application/json" -d "${post_data}" # works

post_data='{"runmode": "msa-redshift", "zfile": "gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits"}'

curl -X POST "$(terraform output -raw container_endpoint)/" -H "X-Auth-Token: $(terraform output -raw secret_key)" -H "Content-Type: application/json" -d '${post_data}' # wrong

```

## To Do:

- set up to launch from queue trigger
- cache templates for different gratings
- figure out how to get metrics back for monitoring containers
- implement fitting at fixed redshift

