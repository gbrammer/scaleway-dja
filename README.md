# scaleway-dja
Scaleway resources for the DJA

```bash
# make an environment shortcut to this repo
echo "export SCWREPO=${PWD}" >> ~/.bashrc
```

## Generate API keys
https://console.scaleway.com/iam/users

## Add SSH key
https://console.scaleway.com/project/ssh-keys

## Install the Scaleway CLI

```bash
brew install scw

scw init
```

## Install terraform

https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

https://www.scaleway.com/en/docs/tutorials/deploy-instances-packer-terraform/

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

brew tap hashicorp/tap
brew install hashicorp/tap/packer

```

## Set up `awscli` for object storage

Scaleway object storage is compatible with the `awscli` command-line tools, e.g., `aws s3 ls ${BUCKET}/{file}`.  See the setup information in [s3init](s3init).


## Set up cockpit logs

See [cockpit-log](cockpit-log).

(Probably only has to be run once when initializing the Project.)

## processor-instance

This is the main tool for setting up a grizli + msaexp processing environment on Scaleway compute instances.  See [processor-instance](processor-instance).


