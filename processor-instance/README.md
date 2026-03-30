
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

name_prefix=worker

instance_count=1

max_process_locks=2
volume_size=16

instance_type=GP1-XS
instance_type=DEV1-L # 4C / 8G
snapshot_name=snap-grizli-processor4-x86

app_process_types=another

instance_type=BASIC2-A4C-16G
snapshot_name=snap-grizli-processor5-arm64

app_process_types=assoc_msa_ifu_ifu-product

instance_count=4
instance_type=BASIC2-A8C-32G
max_process_locks=4
app_process_types=msa
volume_size=24

instance_count=1
max_process_locks=3
volume_size=18
app_process_types=ifu-product


instance_count=4
max_process_locks=4
volume_size=16
app_process_types=ifu

##### set variable arguments using specifications above
cat <<EOF > $PWD/terraform.tfvars

instance_count = ${instance_count}
instance_type = "${instance_type}"
snapshot_name = "${snapshot_name}"
name_prefix = "${name_prefix}"
volume_size = ${volume_size}
max_process_locks = ${max_process_locks}
app_process_types = "${app_process_types}"

EOF

cat terraform.tfvars

##### send terraform plan and launch instances
terraform plan
terraform apply -auto-approve

##### shutdown
terraform destroy -auto-approve
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