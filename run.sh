#!/usr/bin/env bash
set -euo pipefail

##########
APP="spotifyslackstatus"
pushd $APP
[ -d .terraform ] || terraform init
terraform fmt
terraform validate
terraform plan

echo -n "Proceed with deploying $APP? [N/y]: "
read -r APPLY_TF
case $APPLY_TF in
    Y|y)
        terraform apply
        ;;
esac
popd
