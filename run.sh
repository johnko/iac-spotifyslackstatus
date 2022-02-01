#!/usr/bin/env bash
set -euo pipefail

##########
APP="spotifyslackstatus"
pushd $APP

# replace variables
TERRAFORM_VERSION="$( terraform -version | grep Terraform | cut -d' ' -f2 )"
GIT_COMMIT="$( git rev-parse --short=7 HEAD )"
cat provider.template \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > provider.tf

# use the new remote backend
cat backend.template \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > backend.tf

[  -e lambda_function_payload.zip ] && rm lambda_function_payload.zip
zip lambda_function_payload.zip index.py

[ -d .terraform ] || terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
popd
