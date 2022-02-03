#!/usr/bin/env bash
set -euo pipefail

# Need the PowerUserAccess and IAMFullAccess AWS SSO / IAM PermissionSet

echo -n "Input your AWS_ACCOUNT_ID: "
read -r AWS_ACCOUNT_ID
export AWS_ACCOUNT_ID
echo $AWS_ACCOUNT_ID


AWS_REGION="ca-central-1"
##########
APP="spotifyslackstatus"
pushd $APP


# replace variables
TERRAFORM_VERSION="$( terraform -version | grep -v 'Your version of Terraform' | grep Terraform | cut -d' ' -f2 )"
GIT_COMMIT="$( git rev-parse --short=7 HEAD )"
cat provider.template \
    | sed "s,AWS_REGION,$AWS_REGION," \
    | sed "s,AWS_ACCOUNT_ID,$AWS_ACCOUNT_ID," \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > provider.tf

# use the new remote backend
cat backend.template \
    | sed "s,AWS_REGION,$AWS_REGION," \
    | sed "s,AWS_ACCOUNT_ID,$AWS_ACCOUNT_ID," \
    | sed "s,APP_NAME,$APP," \
    | sed "s,TERRAFORM_VERSION,$TERRAFORM_VERSION," \
    | sed "s,GIT_COMMIT,$GIT_COMMIT," \
    > backend.tf

[  -e index.zip ] && rm index.zip
zip index.zip index.py

[ -d .terraform ] || terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
popd
