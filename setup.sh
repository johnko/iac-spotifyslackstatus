#!/usr/bin/env bash
set -euo pipefail

# Need the PowerUserAccess AWS SSO / IAM PermissionSet

##########
APP="tf-remote-backend"
pushd $APP

# deploy state bucket and statelock table using local state
mv backend.tf ../backend.tf
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# use the new remote backend
mv ../backend.tf backend.tf
terraform init
terraform plan

popd
