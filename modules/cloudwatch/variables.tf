variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storage metrics (optional)"
  type        = string
  default     = ""
}
