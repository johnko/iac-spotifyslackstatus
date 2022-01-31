#!/usr/bin/env bash
set -euo pipefail

# Need the PowerUserAccess AWS SSO / IAM PermissionSet

##########
APP="tf-remote-backend"
pushd $APP

# replace variables
TERRAFORM_VERSION="$( terraform -version | grep Terraform | cut -d' ' -f2 )"
GIT_COMMIT="$( git rev-parse --short=7 HEAD )"
cat provider.template \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > provider.tf

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
