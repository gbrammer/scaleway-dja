# Test function

https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/function

```bash

terraform init

./build.sh       # rebuild when requirements or handlers changes, best do by hand

### Environment secrets
cat <<EOF > terraform.tfvars

DB_HOST = ""
DB_USER = ""
DB_PASS = ""
DB_NAME = ""

COCKPIT_LOG_URL = ""
COCKPIT_API_KEY = ""
COCKPIT_LOG_TOKEN = ""

AWS_ACCESS_KEY_ID = ""
AWS_SECRET_ACCESS_KEY = ""

SCW_AWS_ACCESS_KEY_ID = ""
SCW_AWS_SECRET_ACCESS_KEY = ""

EOF

terraform plan
terraform apply -auto-approve # seems to push multiple versions to the container repo

curl -H "X-Auth-Token: $(terraform output -raw secret_key)" \
    "https://$(terraform output -raw function_endpoint)/"

terraform destroy -auto-approve
```