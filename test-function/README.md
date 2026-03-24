# Test function

https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/function

```bash

terraform init

./build.sh

terraform plan
terraform apply -auto-approve

curl -H "X-Auth-Token: $(terraform output -raw secret_key)" \
    "https://$(terraform output -raw function_endpoint)/"

terraform destroy -auto-approve
```