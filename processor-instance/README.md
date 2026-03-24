
# Manage instances with terraform

## Launch processing instances

```bash
cd $SCWREPO/processor-instance/terraform/build # initial build

cd $SCWREPO/processor-instance/terraform       # launch from snapshots

```
 
## Set up instances

https://www.scaleway.com/en/pricing/virtual-instances/?zone=fr-par-1

https://www.scaleway.com/en/docs/instances/reference-content/instances-datasheet/

https://www.scaleway.com/en/docs/instances/reference-content/understanding-differences-x86-arm/

- **x86**: better software compatibility, perhaps better single-thread performance
- **arm**: cheaper, more energy efficient, scalable

```bash

instance_count=1

max_process_locks=2
volume_size=16

instance_type=GP1-XS
instance_type=DEV1-L # 4C / 8G
snapshot_name=snap-grizli-processor4-x86

instance_type=BASIC2-A4C-16G
snapshot_name=snap-grizli-processor5-arm64

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

### set variable arguments using specifications above
INIT_VARS="-var instance_count=$instance_count -var instance_type=${instance_type} -var snapshot_name=${snapshot_name} -var name_prefix=${name_prefix} -var volume_size=${volume_size} -var max_process_locks=$max_process_locks -var app_process_types=${app_process_types}"

echo $INIT_VARS | sed "s/-var/\n -var/g"

### send terraform plan and launch instances
terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

### shutdown
terraform destroy $INIT_VARS -auto-approve
```

## Connect to instance

```bash
SCW_INSTANCE_IP=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`
grep -v $SCW_INSTANCE_IP ~/.ssh/known_hosts > /tmp/hosts; mv /tmp/hosts ~/.ssh/known_hosts; ssh root@${SCW_INSTANCE_IP}

./connect_to_instance.sh  #  script with the above lines
```

## jupyter

```bash
SCW_INSTANCE_IP=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`

ssh -N -f -L 8898:localhost:8888 root@${SCW_INSTANCE_IP}

open "https://localhost:8898"
```

## flask server

```bash
SCW_INSTANCE_IP=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`

open "http://${SCW_INSTANCE_IP}:8080"
```