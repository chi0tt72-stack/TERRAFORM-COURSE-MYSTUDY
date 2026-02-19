# TERRAFORM-COURSE-MYSTUDY

My Terraform Testing Repo — AWS infrastructure with modular design.

## Project Structure

```
├── modules/
│   ├── networking/     # VPC, subnets, internet gateway
│   ├── compute/        # EC2 instances, security groups
│   └── storage/        # S3 bucket
├── environments/
│   └── dev/            # Dev environment config
└── .gitignore
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured (or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars)

## Quick Start

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

## Configuration

1. Copy the example vars: `cp terraform.tfvars.example terraform.tfvars`
2. Edit `terraform.tfvars` with your values (region, bucket prefix, etc.)
3. **Note:** `terraform.tfvars` is gitignored — never commit secrets

## What Gets Created (Dev)

| Resource | Description |
|----------|-------------|
| VPC | 10.0.0.0/16 with public subnets |
| EC2 | t3.micro instance(s) in public subnet |
| S3 | Bucket for storage (name includes random suffix) |
| Security Group | SSH (22) and HTTP (80) allowed |

## Outputs

After `terraform apply`:

- `vpc_id` — VPC ID
- `instance_public_ips` — EC2 public IPs
- `instance_public_dns` — EC2 public DNS names
- `s3_bucket_name` — S3 bucket name

## Cleanup

```bash
cd environments/dev
terraform destroy
```

## Git Workflow

```bash
git add .
git commit -m "your message"
git push
```

## Git Commands that are good to know
```
git checkout main 
git checkout tf-env-fix
git fetch origin
git merge origin/main
git push origin your-branch-name
```

## More Good to Know 

To merge a branch into main in Git, switch to the main branch (git checkout main), pull the latest changes (git pull origin main), and merge your feature branch using git merge <branch-name>. Resolve any conflicts, then push the updated main to the remote repository. 

Local Git Command Line Steps

```
Switch to the main branch:
git checkout main
Pull the latest changes from remote:
git pull origin main
Merge your feature branch into main:
git merge <your-branch-name>
Push the changes to remote:
git push origin main 
```
