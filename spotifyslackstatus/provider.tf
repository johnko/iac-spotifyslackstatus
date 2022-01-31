provider "aws" {
  default_tags {
    tags = {
      app                = "spotifyslackstatus"
      iacdeployer        = "terraform"
      iacdeployerversion = "TERRAFORM_VERSION" # Value from: terraform -version
      iacgitcommit       = "GIT_COMMIT"        # Value from: git rev-parse --short=7 HEAD
    }
  }
  region      = "ca-central-1"
  max_retries = 5

  skip_get_ec2_platforms  = true
  skip_metadata_api_check = true
}
