provider "aws" {
  default_tags {
    tags = {
      app                = "tf-remote-backend"
      iacdeployer        = "terraform"
      iacdeployerversion = "v1.1.4"  # Value from: terraform -version
      iacgitcommit       = "be50288" # Value from: git rev-parse --short=7 HEAD
    }
  }
  region      = "ca-central-1"
  max_retries = 5

  skip_get_ec2_platforms  = true
  skip_metadata_api_check = true
}
