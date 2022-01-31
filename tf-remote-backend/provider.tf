provider "aws" {
  default_tags {
    tags = {
      app = "tf-remote-backend"
    }
  }
  region      = "ca-central-1"
  max_retries = 5

  skip_get_ec2_platforms  = true
  skip_metadata_api_check = true
}
