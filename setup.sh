#!/usr/bin/env bash
set -euo pipefail

# Need the PowerUserAccess AWS SSO / IAM PermissionSet

echo -n "Input your AWS_ACCOUNT_ID: "
read -r AWS_ACCOUNT_ID
export AWS_ACCOUNT_ID
echo $AWS_ACCOUNT_ID


##########
APP="tf-remote-backend"
pushd $APP


# replace variables
TERRAFORM_VERSION="$( terraform -version | grep Terraform | cut -d' ' -f2 )"
GIT_COMMIT="$( git rev-parse --short=7 HEAD )"
cat provider.template \
    | sed "s,AWS_ACCOUNT_ID,$AWS_ACCOUNT_ID," \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > provider.tf

# deploy state bucket and statelock table using local state
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# use the new remote backend
cat backend.template \
    | sed "s,AWS_ACCOUNT_ID,$AWS_ACCOUNT_ID," \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > backend.tf
terraform init
terraform plan

popd
