# SSH Key Pair for EC2 Access
# Public key stored securely in GitLab CI/CD Variables
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${var.project_name}-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

