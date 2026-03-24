
# Manage instances with terraform

## Launch processing instances

```bash
cd $SCWREPO/processor-instance/terraform
```
 
## Set up instances

https://www.scaleway.com/en/pricing/virtual-instances/?zone=fr-par-1

```bash

instance_count=1

instance_type=GP1-XS
max_process_locks=2
volume_size=16

instance_type=GP1-XS
instance_type=DEV1-L # 4C / 8G
snapshot_name=snap-grizli-processor4-x86

instance_type=BASIC2-A4C-16G
snapshot_name=snap-grizli-processor4-arm64

name_prefix=worker

app_process_types=assoc_msa_ifu_ifu-product


instance_count=1
max_process_locks=3
volume_size=18
app_process_types=ifu-product


instance_count=4
max_process_locks=4
volume_size=16
app_process_types=ifu


INIT_VARS="-var instance_count=$instance_count -var max_process_locks=$max_process_locks -var instance_type=${instance_type} -var snapshot_name=${snapshot_name} -var name_prefix=${name_prefix} -var volume_size=${volume_size} -var app_process_types=${app_process_types}"

echo $INIT_VARS | sed "s/-var/\n -var/g"

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