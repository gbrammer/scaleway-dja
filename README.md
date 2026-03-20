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

## 