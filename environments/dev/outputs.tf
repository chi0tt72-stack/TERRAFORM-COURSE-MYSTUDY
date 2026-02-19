output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "instance_public_ips" {
  description = "Public IPs of EC2 instances"
  value       = module.compute.instance_public_ips
}

output "instance_public_dns" {
  description = "Public DNS of EC2 instances"
  value       = module.compute.instance_public_dns
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.storage.bucket_id
}
