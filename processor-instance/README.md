
# Manage instances with terraform

## Build the environment

```bash
cd $SCWREPO/processor-instance/build/terraform

terraform plan
terraform apply -auto-approve

### Run commands in `startup.sh` on the instance
SCWDOCKER=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`
grep -v $SCWDOCKER ~/.ssh/known_hosts > /tmp/hosts; mv /tmp/hosts ~/.ssh/known_hosts; ssh root@${SCWDOCKER}

### Set local environment variables
cat <<EOF >> /root/setup_environment.sh

export DB_HOST=xxx
export DB_USER=xxx
export DB_PASS=xxx
export DB_NAME=xxx

export COCKPIT_LOG_URL=https://xxx.logs.cockpit.fr-par.scw.cloud
export COCKPIT_LOG_TOKEN=xxx
EOF

```

# Launch processing instances

```bash
cd $SCWREPO/processor-instance/terraform
```

## Set up instances
```bash

instance_count=1

#### instance_type=POP2-2C-8G
instance_type=POP2-4C-16G
max_process_locks=2

volume_size=16

server_image=img-grizli-processor3

name_prefix=worker
app_process_types=assoc_ifu_msa

INIT_VARS="-var instance_count=$instance_count -var max_process_locks=$max_process_locks -var instance_type=${instance_type} -var server_image=${server_image} -var name_prefix=${name_prefix} -var volume_size=${volume_size} -var app_process_types=${app_process_types}"

echo $INIT_VARS

### Send it
terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

### Shutdown
terraform destroy $INIT_VARS
```

## Connect to instance
```bash
SCWDOCKER=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`
grep -v $SCWDOCKER ~/.ssh/known_hosts > /tmp/hosts; mv /tmp/hosts ~/.ssh/known_hosts; ssh root@${SCWDOCKER}
```

## Jupyter
```bash
ssh -N -f -L 8898:localhost:8888 root@${SCWDOCKER}
open "https://localhost:8898"
```

## flask

```bash
open "http://${SCWDOCKER}:8080"
```