provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 4
}

terraform {
  backend "s3" {
    bucket = "my-terraform-study-dev-1234567890"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  availability_zones   = var.availability_zones
  tags                 = var.tags
}

module "compute" {
  source = "../../modules/compute"

  environment     = var.environment
  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.public_subnet_ids
  instance_count  = var.instance_count
  instance_type   = var.instance_type
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  tags            = var.tags
}

module "storage" {
  source = "../../modules/storage"

  environment       = var.environment
  bucket_prefix     = var.bucket_prefix
  random_suffix     = random_id.suffix.hex
  versioning_enabled = var.s3_versioning_enabled
  tags              = var.tags
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment              = var.environment
  aws_region               = var.aws_region
  instance_ids             = module.compute.instance_ids
  s3_bucket_name           = module.storage.bucket_id
  cpu_alarm_threshold      = var.cpu_alarm_threshold
  enable_sns_notifications = var.enable_sns_notifications
}
