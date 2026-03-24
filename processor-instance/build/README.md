
# Manage instances with terraform

## Build the environment

```bash
cd $SCWREPO/processor-instance/build

instance_type=GP1-XS        # x86
instance_type=BASIC2-A4C-8G # arm

INIT_VARS="-var instance_count=1 -var instance_type=${instance_type} -var server_image=ubuntu_jammy -var name_prefix=build"

terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

terraform destroy $INIT_VARS

### Run commands in `startup.sh` on the instance
../terraform/connect_to_instance.sh

### Set local environment variables
cat <<EOF >> /root/setup_environment.sh

export DB_HOST=xxx
export DB_USER=xxx
export DB_PASS=xxx
export DB_NAME=xxx

export MAST_TOKEN=xxxxxxxx

export COCKPIT_LOG_URL=https://xxx.logs.cockpit.fr-par.scw.cloud
export COCKPIT_LOG_TOKEN=xxx
export COCKPIT_API_KEY=xxxxxxxxxx

EOF

### On remote machine, create a snapshot+image with the scaleway API
scw_volume_id=`scw block volume list | tail -1 | awk '{print $1}'`

snapshot_suffix=grizli-processor4-x86

arch=x86_64
arch=arm64

snapshot_suffix=grizli-processor4-${arch}

scw block snapshot create ${scw_volume_id} name=snap-${snapshot_suffix} zone=fr-par-1

scw_snapshot_id=`scw block snapshot list | grep ${snapshot_suffix} | awk '{print $1}'`

scw instance image create name=img-${snapshot_suffix} snapshot-id=${scw_snapshot_id} arch=${arch} public=false zone=fr-par-1

scw block snapshot list
scw instance image list

### Delete the image/snapshot pair
scw_image_id=`scw instance image list | grep ${snapshot_suffix} | awk '{print $1}'`
scw instance image delete ${scw_image_id} zone=fr-par-1 with-snapshots=true

```
