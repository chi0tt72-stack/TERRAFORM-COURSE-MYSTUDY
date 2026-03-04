# Terraform AWS Infrastructure Project — Complete Guide

This document provides a verbose, detailed description of this Terraform project: what it is, what it creates, how it is structured, and how to run it.

---

## Table of Contents

1. [What Is This Project?](#what-is-this-project)
2. [Project Structure](#project-structure)
3. [Architecture Overview](#architecture-overview)
4. [Module Descriptions](#module-descriptions)
5. [Data Flow and Dependencies](#data-flow-and-dependencies)
6. [Prerequisites](#prerequisites)
7. [Configuration](#configuration)
8. [How to Run It](#how-to-run-it)
9. [Outputs](#outputs)
10. [State Management](#state-management)
11. [Cleanup](#cleanup)

---

## What Is This Project?

This is a **modular Terraform project** that provisions a complete AWS infrastructure stack. It is designed for learning Terraform, testing infrastructure-as-code patterns, and standing up a development or lab environment in AWS.

The project creates:

- **Networking** — A Virtual Private Cloud (VPC) with public subnets, an internet gateway, and routing so resources can reach the internet
- **Compute** — EC2 instances running Amazon Linux 2023, with security groups allowing SSH and HTTP traffic
- **Storage** — An S3 bucket with optional versioning and all public access blocked
- **Monitoring** — CloudWatch alarms for EC2 CPU and status checks, a CloudWatch dashboard showing EC2 and S3 metrics, and an SNS topic for alarm notifications

Everything is defined as code, versioned, and can be reproduced or torn down with Terraform commands.

---

## Project Structure

```
TERRAFORM-COURSE-MYSTUDY/
├── modules/
│   ├── networking/          # VPC and network resources
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/             # EC2 instances and security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/             # S3 bucket
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cloudwatch/          # Monitoring and alerting
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   └── dev/                 # Development environment
│       ├── main.tf          # Orchestrates all modules
│       ├── variables.tf     # Input variables
│       ├── outputs.tf       # Exposed outputs
│       ├── versions.tf      # Terraform version, providers, backend
│       ├── terraform.tfvars.example
│       └── terraform.tfvars # Your values (gitignored)
└── README_TERRAFORM.md      # This file
```

The **environments/dev** directory is the root where you run Terraform. It composes the four modules and passes variables between them.

---

## Architecture Overview

```
                         Internet
                              │
                              ▼
                    ┌─────────────────────┐
                    │  Internet Gateway   │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     │
┌─────────────────┐  ┌─────────────────┐            │
│ Public Subnet 1  │  │ Public Subnet 2  │            │
│ 10.0.1.0/24     │  │ 10.0.2.0/24     │            │
│ (e.g. us-east-1a)│  │ (e.g. us-east-1b)│            │
│                 │  │                 │            │
│  ┌───────────┐  │  │  ┌───────────┐  │            │
│  │ EC2       │  │  │  │ EC2       │  │            │
│  │ Instance  │  │  │  │ Instance  │  │            │
│  └───────────┘  │  │  └───────────┘  │            │
└─────────────────┘  └─────────────────┘            │
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │        VPC          │
                    │   (e.g. 10.0.0.0/16)│
                    └─────────────────────┘

         Outside VPC (regional AWS services):
         ┌─────────────────────────────────────────┐
         │ S3 Bucket                                │
         │ CloudWatch Dashboard                     │
         │ SNS Topic (alarm notifications)          │
         └─────────────────────────────────────────┘
```

---

## Module Descriptions

### 1. Networking Module (`modules/networking`)

**Purpose:** Creates the network foundation for the environment.

**Resources:**

| Resource | Description |
|----------|-------------|
| `aws_vpc.main` | VPC with configurable CIDR (e.g., 10.0.0.0/16). DNS hostnames and DNS support enabled. |
| `aws_internet_gateway.main` | Internet gateway attached to the VPC. |
| `aws_subnet.public` | Public subnets, one per CIDR in `public_subnet_cidrs`, each in a different availability zone. `map_public_ip_on_launch = true` so instances get public IPs. |
| `aws_route_table.public` | Route table with a default route (0.0.0.0/0) to the internet gateway. |
| `aws_route_table_association.public` | Associates each public subnet with the public route table. |

**Inputs:** `environment`, `vpc_cidr`, `public_subnet_cidrs`, `availability_zones`, `tags`

**Outputs:** `vpc_id`, `public_subnet_ids`

---

### 2. Compute Module (`modules/compute`)

**Purpose:** Launches EC2 instances and controls network access.

**Resources:**

| Resource | Description |
|----------|-------------|
| `data.aws_ami.amazon_linux` | Looks up the latest Amazon Linux 2023 AMI (al2023-ami-*-x86_64). |
| `aws_security_group.instance` | Security group with: SSH (22) from `allowed_ssh_cidrs`, HTTP (80) from 0.0.0.0/0, and egress to 0.0.0.0/0. |
| `aws_instance.main` | EC2 instances. Count = `instance_count`. Uses the looked-up AMI (or `ami_id` if set). Instances are spread across subnets using modulo. |

**Inputs:** `environment`, `vpc_id`, `subnet_ids`, `instance_count`, `instance_type`, `allowed_ssh_cidrs`, `tags`, optional `ami_id`

**Outputs:** `instance_ids`, `instance_public_ips`, `instance_public_dns`

---

### 3. Storage Module (`modules/storage`)

**Purpose:** Creates an S3 bucket for object storage.

**Resources:**

| Resource | Description |
|----------|-------------|
| `aws_s3_bucket.main` | S3 bucket. Name: `{bucket_prefix}-{environment}-{random_suffix}`. |
| `aws_s3_bucket_versioning.main` | Enables or suspends versioning based on `versioning_enabled`. |
| `aws_s3_bucket_public_access_block.main` | Blocks public ACLs, public policies, and public bucket access. |

**Inputs:** `environment`, `bucket_prefix`, `random_suffix`, `versioning_enabled`, `tags`

**Outputs:** `bucket_id`

---

### 4. CloudWatch Module (`modules/cloudwatch`)

**Purpose:** Adds monitoring and alerting for EC2 and S3.

**Resources:**

| Resource | Description |
|----------|-------------|
| `aws_sns_topic.cloudwatch_alarms` | SNS topic for alarm notifications. |
| `aws_cloudwatch_metric_alarm.ec2_cpu_high` | One alarm per EC2 instance. Triggers when CPU utilization exceeds `cpu_alarm_threshold` (default 80%) for 2 evaluation periods of 5 minutes. |
| `aws_cloudwatch_metric_alarm.ec2_status_check` | One alarm per EC2 instance. Triggers when EC2 status check fails (metric > 0). |
| `aws_cloudwatch_dashboard.main` | Dashboard with widgets for: EC2 CPU, Network In, Network Out (per instance), S3 bucket size, S3 object count, and a summary text widget. |

**Inputs:** `environment`, `aws_region`, `instance_ids`, `s3_bucket_name`, `cpu_alarm_threshold`, `enable_sns_notifications`

**Outputs:** `dashboard_name`, `dashboard_arn`, `sns_topic_arn`, `alarm_names`

---

## Data Flow and Dependencies

```
main.tf (environments/dev)
    │
    ├── random_id.suffix  ──────────────────────────► storage (random_suffix)
    │
    ├── networking  ──► vpc_id, public_subnet_ids
    │                        │
    │                        └──────────────────────► compute (vpc_id, subnet_ids)
    │
    ├── compute  ──► instance_ids, instance_public_ips, instance_public_dns
    │                        │
    │                        └──────────────────────► cloudwatch (instance_ids)
    │
    ├── storage  ──► bucket_id
    │                        │
    │                        └──────────────────────► cloudwatch (s3_bucket_name)
    │
    └── cloudwatch  ──► dashboard_name, sns_topic_arn, alarm_names
```

The networking module runs first (no dependencies). Compute depends on networking. Storage and CloudWatch depend on compute and storage outputs.

---

## Prerequisites

Before running this project, you need:

1. **Terraform** — Version 1.0 or later. [Download Terraform](https://www.terraform.io/downloads).

2. **AWS credentials** — Configured via one of:
   - `aws configure` (AWS CLI)
   - Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (if using temporary credentials)
   - IAM role (e.g., on EC2, ECS, or similar)

3. **S3 backend access** — The project uses an S3 backend for Terraform state. Ensure you have read/write access to the bucket configured in `environments/dev/versions.tf` (e.g., `multivar-databricks-chiottcbucket`). If using a different bucket, update the backend block.

4. **Permissions** — Your AWS credentials must allow creating and managing VPCs, EC2 instances, S3 buckets, CloudWatch alarms/dashboards, SNS topics, and related resources.

---

## Configuration

### Step 1: Copy the example variables file

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Edit `terraform.tfvars`

`terraform.tfvars` holds your environment-specific values. Terraform loads it automatically.

**Example configuration:**

```hcl
# AWS Configuration
aws_region   = "us-east-1"
environment  = "dev"

# Networking
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# Compute
instance_count    = 2
instance_type     = "t3.micro"
allowed_ssh_cidrs = ["0.0.0.0/0"]   # Restrict to your IP in production

# Storage
bucket_prefix         = "my-terraform-study"
s3_versioning_enabled = true

# CloudWatch
cpu_alarm_threshold      = 80
enable_sns_notifications = true

# Tags
tags = {
  Project     = "terraform-study"
  Environment = "dev"
  ManagedBy   = "terraform"
}
```

**Important:** `terraform.tfvars` is typically gitignored. Do not commit secrets or sensitive data.

### Step 3: Backend configuration (optional)

If you use a different S3 bucket for state, edit `environments/dev/versions.tf`:

```hcl
backend "s3" {
  bucket = "your-terraform-state-bucket"
  key    = "terraform.tfstate"
  region = "us-east-1"
}
```

---

## How to Run It

All commands are run from `environments/dev`.

### 1. Initialize Terraform

Downloads providers and prepares the backend:

```bash
cd environments/dev
terraform init
```

You should see providers (e.g., AWS, random) initialized and the backend configured.

### 2. Plan

Shows what Terraform will create, change, or destroy:

```bash
terraform plan
```

Review the plan before applying.

### 3. Apply

Creates or updates infrastructure:

```bash
terraform apply
```

Terraform will show the plan again and ask for confirmation. Type `yes` to proceed.

### 4. View outputs

After a successful apply:

```bash
terraform output
```

Or specific outputs:

```bash
terraform output instance_public_ips
terraform output cloudwatch_dashboard_name
```

### 5. Format and validate (optional)

```bash
terraform fmt -recursive
terraform validate
```

---

## Outputs

After `terraform apply`, these outputs are available:

| Output | Description |
|--------|-------------|
| `vpc_id` | ID of the created VPC |
| `instance_public_ips` | Public IP addresses of the EC2 instances |
| `instance_public_dns` | Public DNS names of the EC2 instances |
| `s3_bucket_name` | Name of the S3 bucket |
| `cloudwatch_dashboard_name` | Name of the CloudWatch dashboard |
| `cloudwatch_sns_topic_arn` | ARN of the SNS topic for alarm notifications |
| `cloudwatch_alarm_names` | Names of the CloudWatch alarms |

---

## State Management

Terraform state is stored remotely in S3, as defined in `versions.tf`:

```hcl
backend "s3" {
  bucket = "multivar-databricks-chiottcbucket"
  key    = "terraform.tfstate"
  region = "us-east-1"
  use_lockfile = true
}
```

- State is shared across team members and CI/CD.
- State locking helps prevent concurrent modifications.
- Do not edit the state file manually. Use `terraform state` commands if needed.

---

## Cleanup

To destroy all resources created by this project:

```bash
cd environments/dev
terraform destroy
```

Terraform will list the resources to be destroyed and ask for confirmation. Type `yes` to proceed.

**Warning:** This permanently deletes the VPC, EC2 instances, S3 bucket (and its contents), CloudWatch resources, and SNS topic. Ensure you have backups of any important data before running `terraform destroy`.
