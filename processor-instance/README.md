
# Manage instances with terraform

## Launch processing instances

1. [Build](build) the environment
2. [Launch](terraform) from snapshots

```bash

cd $SCWREPO/processor-instance/build      # build the environment

cd $SCWREPO/processor-instance/terraform  # launch from snapshots

```
 
## Set up instances

https://www.scaleway.com/en/pricing/virtual-instances/?zone=fr-par-1

https://www.scaleway.com/en/docs/instances/reference-content/instances-datasheet/

https://www.scaleway.com/en/docs/instances/reference-content/understanding-differences-x86-arm/

- **x86**: better software compatibility, perhaps better single-thread performance
- **arm**: cheaper, more energy efficient, scalable (e.g., ``BASIC2-A8C-32G``)

```bash

cd $SCWREPO/processor-instance/terraform

##### set variable arguments

cat <<EOF > $PWD/thisrun.tfvars

instance_count = 1
instance_type = "BASIC2-A8C-32G"
snapshot_name = "snap-grizli-processor6-arm64"
name_prefix = "worker"
volume_size = 24
max_process_locks = 1
app_process_types = "assoc"

EOF

cat thisrun.tfvars

##### send terraform plan to launch instances
terraform plan -var-file thisrun.tfvars
terraform apply -auto-approve -var-file thisrun.tfvars

##### shutdown
terraform destroy -auto-approve -var-file thisrun.tfvars
```

## Connect to instance

```bash
##### in $SCWREPO/processor-instance/terraform
../connect_to_scw_instance worker00
```

## jupyter

Connect to the instance and launch the jupyter server.  Then run the following to map the remote port to a local port, e.g., ``8898``.

```bash
../connect_to_scw_instance worker00 8898
open "https://localhost:8898"
```

## flask server

```bash
SCW_INSTANCE_IP=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`

open "http://${SCW_INSTANCE_IP}:8080"
```