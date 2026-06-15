
# Manage instances with terraform

https://www.scaleway.com/en/pricing/virtual-instances/?zone=fr-par-1

https://www.scaleway.com/en/docs/instances/reference-content/instances-datasheet/

https://www.scaleway.com/en/docs/instances/reference-content/understanding-differences-x86-arm/

Instance architectures:

- **x86**: better software compatibility, perhaps better single-thread performance
- **arm**: cheaper, more energy efficient, scalable (e.g., ``BASIC2-A8C-32G``)

The bulid scripts below currently only use **arm** instances.

## Set up  instance environment

Install grizli, msaexp, etc. on a Scaleway instance and save a snapshot for generating runner instances.  See [Build](build).

```bash
cd $SCWREPO/processor-instance/build  # build the environment
```
 
## Launch instances

[Launch](terraform) from snapshots created in [Build](build):

```bash

cd $SCWREPO/processor-instance/terraform  # launch from here

##### set variable arguments to override defaults in terraform/main.tf

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

Helper script to get the instance IP and launch an ssh connection:
[connect_to_scw_instance](connect_to_scw_instance).

```bash
##### in $SCWREPO/processor-instance/terraform

##### list instances
../connect_to_scw_instance list

##### ssh connection
../connect_to_scw_instance worker00
```

## Jupyter

1. Connect to the instance with the command above and launch the jupyter server (``$ launch_labserver``).
2. Run the following locally to map the remote jupyterlab port (8888) to a local port, e.g., 8898.

```bash
../connect_to_scw_instance worker00 8898
open "https://localhost:8898"
```

## flask server

*(To be updated.)*

```bash
SCW_INSTANCE_IP=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`

open "http://${SCW_INSTANCE_IP}:8080"
```