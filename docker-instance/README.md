
# Make an instance for building Docker apps

```bash
cd ${SCWREPO}/docker-instance/terraform

terraform init

terraform plan

terraform apply # -auto-approve
```
# Connect to the instance

```bash
export SCWDOCKER=`terraform output | grep address | awk '{print $3}' | sed "s/\"//g"`

## remove potential duplicate from known_hosts
grep -v $SCWDOCKER ~/.ssh/known_hosts > ~/.ssh/known_hosts

ssh root@${SCWDOCKER}
```

# eventually tear down

```bash
terraform destroy
```