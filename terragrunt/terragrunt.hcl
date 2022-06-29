remote_state {
  backend = "s3"
  config = {
    bucket = "acme-terra-state"
    profile = "acme"
    key = "terraform.tfstate"
    region = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}

terraform {
  # For any terraform commands that use locking, make sure to configure a lock timeout of 20 minutes.
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }
  source = "../terraform//."
}

locals {
  config = yamldecode(file("config.yml"))
}

inputs = merge(
  {
    bucket_src = "${local.config.project}-edge-src",
    bucket_dst = "${local.config.project}-edge-dst",
  },
  local.config
)
