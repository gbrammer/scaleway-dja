
# Manage instances with terraform

## Build the environment

```bash
cd $SCWREPO/processor-instance/build

instance_type=GP1-XS         # x86
instance_type=DEV1-XL        # x86
instance_type=BASIC2-A4C-8G  # arm

INIT_VARS="-var instance_count=1 -var instance_type=${instance_type} -var server_image=ubuntu_jammy -var name_prefix=build"

echo $INIT_VARS | sed "s/-var/\n -var/g"

terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

terraform destroy $INIT_VARS -auto-approve
```
### Connect to the instance

```bash
../terraform/connect_to_instance.sh
```

#### Build the environment

Paste commands from [startup.sh](startup.sh) into the remote terminal.

### On local machine, create a snapshot+image with the scaleway CLI

```bash
scw block volume list

scw_volume_id=`scw block volume list | tail -1 | awk '{print $1}'`

uname -m      # on instance
arch=x86_64
arch=arm64

snapshot_suffix=grizli-processor5-${arch}

scw block snapshot create ${scw_volume_id} name=snap-${snapshot_suffix} zone=fr-par-1
```

### done; don't generate images as below

```bash
scw_snapshot_id=`scw block snapshot list | grep ${snapshot_suffix} | awk '{print $1}'`

scw instance image create name=img-${snapshot_suffix} snapshot-id=${scw_snapshot_id} arch=${arch} public=false zone=fr-par-1

 # scw instance image create name=img-${snapshot_suffix} snapshot-id=${scw_snapshot_id} arch=${arch} public=false zone=fr-par-1

scw block snapshot list
scw instance image list

### Delete the image/snapshot pair
scw_image_id=`scw instance image list | grep ${snapshot_suffix} | awk '{print $1}'`
scw instance image delete ${scw_image_id} zone=fr-par-1 with-snapshots=true

```
