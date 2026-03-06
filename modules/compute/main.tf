data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Retrieve SSH public key from AWS Secrets Manager
data "aws_secretsmanager_secret" "ssh_key" {
  name = "terraform/ssh-public-key"
}

data "aws_secretsmanager_secret_version" "ssh_key" {
  secret_id = data.aws_secretsmanager_secret.ssh_key.id
}

# SSH Key Pair for EC2 Access
resource "aws_key_pair" "main" {
  key_name   = "${var.environment}-key"
  public_key = data.aws_secretsmanager_secret_version.ssh_key.secret_string
  
  tags = merge(var.tags, {
    Name = "${var.environment}-key"
  })
}

resource "aws_security_group" "instance" {
  name        = "${var.environment}-instance-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-instance-sg"
  })
}

resource "aws_instance" "main" {
  count         = var.instance_count
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]

  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = aws_key_pair.main.key_name
  
  tags = merge(var.tags, {
    Name = "${var.environment}-instance-${count.index + 1}"
  })
}
