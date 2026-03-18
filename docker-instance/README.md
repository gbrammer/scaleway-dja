
# Make an instance for building Docker apps

```bash
cd ${SCWREPO}/docker-instance/terraform

terraform init

terraform plan

terraform apply # -auto-approve
```
# Connect to the instance

```bash
export SCWDOCKER=`terraform output | grep address | awk '{print $3}' | sed "s/\"//g"`

## remove potential duplicate from known_hosts
grep -v $SCWDOCKER ~/.ssh/known_hosts > ~/.ssh/known_hosts

ssh root@${SCWDOCKER}

## Build the docker image

cd /root/scaleway-dja/docker-instance/ProcessingApp/

container_namespace=ns-dja-containers
docker login rg.fr-par.scw.cloud/${container_namespace} -u nologin # enter SCW_SECRET_KEY

app_tag=dja-processor
git pull

docker build -t ${app_tag} .

### Test it
test="""
    docker run -it --env-file ./.env --entrypoint /bin/bash ${app_tag}
    python app.py --ifu --fixed
    python app.py --msa --fixed
    python app.py --assoc --fixed
    python app.py --ifu-product --fixed
"""

## Tag and push to container repository
docker tag ${app_tag}:latest rg.fr-par.scw.cloud/${container_namespace}/${app_tag}:latest

docker push rg.fr-par.scw.cloud/${container_namespace}/${app_tag}:latest

```

# eventually tear down

```bash
terraform destroy
```