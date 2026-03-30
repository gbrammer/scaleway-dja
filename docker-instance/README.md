
# Make an instance for building Docker apps

```bash
cd ${SCWREPO}/docker-instance/terraform

terraform init

terraform plan

terraform apply # -auto-approve
```
# Connect to the instance

```bash
./connect_to_instance.sh

##### Build the docker image

cd /root/scaleway-dja/docker-instance/SpectrumApp/

container_namespace=ns-dja-containers
docker login rg.fr-par.scw.cloud/${container_namespace} -u nologin # enter SCW_SECRET_KEY

app_tag=dja-processor
git pull

docker build -t ${app_tag} .

git pull; docker build -t ${app_tag} .; docker run -it --env-file /root/docker_environment.txt --entrypoint /bin/bash ${app_tag}

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

# Finally tear down

```bash
terraform destroy
```