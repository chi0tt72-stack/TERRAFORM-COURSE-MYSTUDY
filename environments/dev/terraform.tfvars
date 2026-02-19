aws_region            = "us-east-1"
environment           = "terraformtest"
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones    = ["us-east-1a", "us-east-1b"]
instance_count        = 1
instance_type         = "t3.micro"
allowed_ssh_cidrs     = ["0.0.0.0/0"]
bucket_prefix         = "chiotttfprojecttest"
s3_versioning_enabled = true

tags = {
  Project     = "terraform-course-cursor"
  Environment = "dev-cursor"
  ManagedBy   = "terraform"
}
