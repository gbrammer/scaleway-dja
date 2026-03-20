
# Manage instances with terraform

```bash

INIT_VARS="-var instance_count=1 -var instance_type=DEV1-L -var server_image=ubuntu_jammy -var name_prefix=build"
terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

#### Connect to instance
SCWDOCKER=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`
#### grep -v $SCWDOCKER ~/.ssh/known_hosts > ~/.ssh/known_hosts

ssh root@${SCWDOCKER}


```