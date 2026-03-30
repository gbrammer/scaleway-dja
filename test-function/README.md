# Test function

    Lots of experimentation trying to get an environment to work with
    serverless functions, but never worked very well.  In the end it seems like
    most of the same functionality can be achieved with serverless containers,
    which are much easier to set up with Docker environments and more standard
    Linux distro.
    
https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/function

## Build on an amd64 instance

```bash
cd $SCWREPO/processor-instance/terraform

######   params       ######################
name_prefix=builder

instance_count=1
volume_size=32

max_process_locks=2
app_process_types=another

instance_type=DEV1-L                       # 4C / 8G
snapshot_name=snap-grizli-processor4-x86
#####################################

cat <<EOF > $PWD/terraform.tfvars

instance_count = ${instance_count}
instance_type = "${instance_type}"
snapshot_name = "${snapshot_name}"
name_prefix = "${name_prefix}"
volume_size = ${volume_size}
max_process_locks = ${max_process_locks}

EOF

cat terraform.tfvars

######   launch       ######################
terraform plan
terraform apply -auto-approve

./connect_to_instance.sh

terraform destroy -auto-approve

```

## Build function
```bash

terraform init

./build.sh       # rebuild when requirements or handlers changes, best do by hand

######   Environment secrets       ############
cat <<EOF > terraform.tfvars

DB_HOST = ""
DB_USER = ""
DB_PASS = ""
DB_NAME = ""

COCKPIT_LOG_URL = ""
COCKPIT_API_KEY = ""
COCKPIT_LOG_TOKEN = ""

AWS_ACCESS_KEY_ID = ""
AWS_SECRET_ACCESS_KEY = ""

SCW_AWS_ACCESS_KEY_ID = ""
SCW_AWS_SECRET_ACCESS_KEY = ""

CRDS_SERVER_URL = "https://jwst-crds.stsci.edu"
CRDS_PATH = "/home/app/function/package/crds_cache"

EOF

terraform plan
terraform apply -auto-approve # seems to push multiple versions to the container repo

######   Test invoke       ####################
curl -H "X-Auth-Token: $(terraform output -raw secret_key)" \
    "https://$(terraform output -raw function_endpoint)/"

terraform destroy -auto-approve
```