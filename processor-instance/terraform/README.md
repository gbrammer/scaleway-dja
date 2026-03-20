
# Manage instances with terraform

```bash

INIT_VARS="-var instance_count=1 -var instance_type=DEV1-L -var server_image=ubuntu_jammy -var name_prefix=build"
terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

INIT_VARS="-var instance_count=1 -var instance_type=DEV1-L -var server_image=processor-build1 -var name_prefix=worker -var volume_size=16"
terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

INIT_VARS="-var instance_count=1 -var instance_type=POP2-4C-16G -var server_image=img-grizli-processor2 -var name_prefix=worker -var volume_size=16"

# INIT_VARS="-var instance_count=4 -var instance_type=POP2-2C-8G -var server_image=img-grizli-processor2 -var name_prefix=worker -var volume_size=16"

terraform plan $INIT_VARS
terraform apply $INIT_VARS -auto-approve

terraform destroy $INIT_VARS

#### Connect to instance
SCWDOCKER=`terraform output | grep address | head -1 | awk '{print $3}' | sed "s/\"//g"`
grep -v $SCWDOCKER ~/.ssh/known_hosts > /tmp/hosts; mv /tmp/hosts ~/.ssh/known_hosts; ssh root@${SCWDOCKER}

#### Jupyter
ssh -N -f -L 8898:localhost:8888 root@${SCWDOCKER}
open "https://localhost:8898"

#### flask
open "http://${SCWDOCKER}:8080"

```