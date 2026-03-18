
# Make an instance for building Docker apps

```bash
$ cd ${SCWREPO}/docker-instance/terraform

$ terraform init

$ terraform plan

$ terraform apply # -auto-approve

# Save the instance IP
$ export SCWDOCKER=`terraform output | grep address | awk '{print $3}' | sed "s/\"//g"`
# eventually
$ terraform destroy
```