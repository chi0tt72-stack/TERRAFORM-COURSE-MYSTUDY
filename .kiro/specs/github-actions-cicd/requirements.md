# Requirements Document

## Introduction

This feature introduces a GitHub Actions CI/CD pipeline as a new, independent deployment path for the existing Terraform + Ansible infrastructure project. The pipeline will authenticate to AWS purely via GitHub OIDC (with zero credentials or secrets stored in GitHub), retrieve all secrets from AWS Secrets Manager at runtime, manage Terraform state in an S3 backend, execute Terraform plan/apply/destroy workflows, and automatically run Ansible playbooks against newly provisioned EC2 instances in an Auto Scaling Group. This is not a migration from the existing GitLab CI/CD pipeline — both pipelines may coexist.

## Glossary

- **Pipeline**: A GitHub Actions workflow that orchestrates CI/CD stages for infrastructure deployment
- **OIDC_Provider**: An AWS IAM OIDC identity provider that trusts GitHub Actions tokens for federated authentication
- **IAM_Role**: An AWS IAM role (GitHubActionsTerraformRole) assumed by the Pipeline via OIDC for AWS access
- **S3_Backend**: An AWS S3 bucket used to store Terraform state files for the GitHub Actions deployment
- **Terraform_Runner**: The component of the Pipeline responsible for executing Terraform commands (init, validate, plan, apply, destroy)
- **Ansible_Runner**: The component of the Pipeline responsible for executing Ansible playbooks against provisioned EC2 instances
- **Auto_Scaling_Group**: An AWS Auto Scaling Group that manages the desired count of EC2 instances (minimum 2) for the deployment
- **Inventory_Generator**: The Terraform local_file resource (ansible.tf) that produces an Ansible inventory file from Terraform outputs, listing all EC2 instances in the Auto_Scaling_Group
- **Secrets_Manager**: AWS Secrets Manager, the sole store for all sensitive values (SSH keys, credentials) used by the Pipeline
- **SSH_Key**: An SSH key pair (public and private) stored in Secrets_Manager, used by the Ansible_Runner to connect to EC2 instances and by Terraform to configure the EC2 key pair
- **Plan_Artifact**: The saved Terraform plan file uploaded as a GitHub Actions artifact between workflow stages
- **Launch_Template**: An AWS EC2 launch template that defines the instance configuration (AMI, instance type, key pair, security groups) used by the Auto_Scaling_Group
- **Web_Application_Stack**: The set of software packages (Apache httpd, PHP, WordPress, Python, MariaDB client) installed and configured on each EC2 instance by the Ansible_Runner
- **ALB**: An AWS Application Load Balancer (internet-facing) that distributes incoming HTTP traffic across EC2 instances in the Auto_Scaling_Group
- **ALB_Security_Group**: An AWS security group attached to the ALB that controls inbound and outbound traffic to the load balancer
- **Target_Group**: An AWS ALB target group that registers EC2 instances in the Auto_Scaling_Group on port 80 and performs health checks
- **ALB_Module**: A Terraform module (modules/alb/) that encapsulates all ALB, Target_Group, listener, and ALB_Security_Group resources

## Requirements

### Requirement 1: GitHub OIDC Authentication to AWS

**User Story:** As a DevOps engineer, I want the GitHub Actions pipeline to authenticate to AWS using OIDC federation, so that no credentials or secrets of any kind are stored in GitHub.

#### Acceptance Criteria

1. THE Pipeline SHALL authenticate to AWS by assuming the IAM_Role via GitHub OIDC token exchange
2. WHEN the OIDC token exchange succeeds, THE Pipeline SHALL export temporary AWS credentials (access key, secret key, session token) for use by subsequent steps
3. IF the OIDC token exchange fails, THEN THE Pipeline SHALL terminate the workflow run with a non-zero exit code and a descriptive error message
4. THE IAM_Role trust policy SHALL restrict access to the specific GitHub repository and branch pattern
5. THE Pipeline SHALL store zero credentials, secrets, or sensitive values in GitHub Actions secrets or GitHub Actions variables

### Requirement 2: IAM Policy for GitHub Actions OIDC

**User Story:** As a DevOps engineer, I want a dedicated IAM OIDC trust policy and permissions policy for GitHub Actions, so that the GitHub deployment is isolated from the existing GitLab deployment.

#### Acceptance Criteria

1. THE IAM_Role SHALL use a trust policy that references the GitHub OIDC_Provider (token.actions.githubusercontent.com)
2. THE IAM_Role trust policy SHALL scope the allowed subject claim to the specific GitHub repository
3. THE IAM_Role SHALL have an attached permissions policy granting access to EC2, Auto Scaling, VPC, S3, CloudWatch, SNS, IAM (GetRole, PassRole), Secrets Manager, KMS, and Elastic Load Balancing (elasticloadbalancing:*) resources
4. THE IAM_Role SHALL be independent from the existing GitLab IAM role

### Requirement 3: Secrets Management via AWS Secrets Manager

**User Story:** As a DevOps engineer, I want all secrets stored exclusively in AWS Secrets Manager, so that the Pipeline retrieves them at runtime after OIDC authentication and no sensitive values exist in GitHub.

#### Acceptance Criteria

1. THE Secrets_Manager SHALL store the SSH private key used by the Ansible_Runner to connect to EC2 instances
2. THE Secrets_Manager SHALL store the SSH public key used by Terraform to create the EC2 key pair resource
3. WHEN the Pipeline authenticates via OIDC, THE Pipeline SHALL retrieve all required secrets from Secrets_Manager before executing Terraform or Ansible steps
4. THE Pipeline SHALL reference Secrets_Manager secret ARNs via non-sensitive GitHub Actions variables or hardcoded workflow values (not GitHub secrets)
5. IF the Pipeline fails to retrieve a secret from Secrets_Manager, THEN THE Pipeline SHALL terminate the workflow with a non-zero exit code and a descriptive error message
6. THE IAM_Role SHALL have permissions to read the specific secrets from Secrets_Manager required by the Pipeline

### Requirement 4: Terraform State Backend Configuration

**User Story:** As a DevOps engineer, I want Terraform state for the GitHub Actions deployment stored in a dedicated S3 backend, so that state is isolated from the GitLab deployment and supports locking.

#### Acceptance Criteria

1. THE Terraform_Runner SHALL use an S3_Backend for remote state storage
2. THE S3_Backend configuration SHALL use S3 native locking (use_lockfile = true) for state locking
3. THE S3_Backend state key SHALL be distinct from any existing GitLab-managed state to prevent conflicts
4. WHEN terraform init runs, THE Terraform_Runner SHALL configure the backend using values provided via -backend-config flags or environment variables

### Requirement 5: Terraform Validate and Plan Stage

**User Story:** As a DevOps engineer, I want Terraform validation and planning to run automatically on pull requests and pushes to main, so that infrastructure changes are reviewed before apply.

#### Acceptance Criteria

1. WHEN a pull request is opened or updated targeting the main branch, THE Pipeline SHALL run terraform validate and terraform fmt -check
2. WHEN a pull request is opened or updated targeting the main branch, THE Pipeline SHALL run terraform plan and save the output as a Plan_Artifact
3. WHEN terraform plan completes on a pull request, THE Pipeline SHALL post the plan summary as a comment on the pull request
4. IF terraform validate or terraform fmt -check fails, THEN THE Pipeline SHALL terminate the workflow with a non-zero exit code

### Requirement 6: Terraform Apply Stage

**User Story:** As a DevOps engineer, I want Terraform apply to run on the main branch with a manual approval gate, so that infrastructure changes are applied deliberately.

#### Acceptance Criteria

1. WHEN a push occurs to the main branch, THE Pipeline SHALL run terraform plan followed by terraform apply
2. THE Pipeline SHALL require a manual approval step (GitHub environment protection rule) before executing terraform apply
3. WHEN terraform apply completes successfully, THE Pipeline SHALL output the Terraform outputs (Auto_Scaling_Group name, instance IPs, VPC ID, bucket name) as workflow outputs
4. IF terraform apply fails, THEN THE Pipeline SHALL terminate the workflow with a non-zero exit code and preserve the Plan_Artifact for debugging

### Requirement 7: Terraform Destroy Stage

**User Story:** As a DevOps engineer, I want a manually triggered workflow to destroy infrastructure, so that resources can be torn down when no longer needed.

#### Acceptance Criteria

1. WHEN the destroy workflow is manually triggered via workflow_dispatch, THE Terraform_Runner SHALL execute terraform destroy -auto-approve
2. THE Pipeline SHALL require a manual approval step (GitHub environment protection rule) before executing terraform destroy
3. WHEN terraform destroy completes successfully, THE Pipeline SHALL log a confirmation message with the destroyed environment name
4. IF terraform destroy fails, THEN THE Pipeline SHALL terminate the workflow with a non-zero exit code

### Requirement 8: EC2 Auto Scaling Group Provisioning

**User Story:** As a DevOps engineer, I want Terraform to provision an Auto Scaling Group with two EC2 instances, so that the deployment has redundancy and can scale.

#### Acceptance Criteria

1. THE Terraform_Runner SHALL provision a Launch_Template defining the EC2 instance configuration (AMI, instance type, key pair, security groups)
2. THE Terraform_Runner SHALL provision an Auto_Scaling_Group that references the Launch_Template
3. THE Auto_Scaling_Group SHALL have a minimum capacity of 2, a desired capacity of 2, and a maximum capacity configurable via a Terraform variable
4. WHEN terraform apply completes, THE Auto_Scaling_Group SHALL contain exactly 2 running EC2 instances
5. THE Auto_Scaling_Group SHALL distribute EC2 instances across available availability zones in the configured AWS region
6. THE Inventory_Generator SHALL query the Auto_Scaling_Group instance IPs and produce an Ansible inventory file listing all 2 instances
7. THE Launch_Template SHALL reference the SSH public key retrieved from Secrets_Manager to configure the EC2 key pair

### Requirement 9: Automated Ansible Configuration After Apply

**User Story:** As a DevOps engineer, I want Ansible playbooks to run automatically after Terraform provisions EC2 instances, so that all instances in the Auto Scaling Group are configured without manual intervention.

#### Acceptance Criteria

1. WHEN terraform apply completes successfully and the Auto_Scaling_Group contains running EC2 instances, THE Pipeline SHALL trigger the Ansible_Runner
2. THE Ansible_Runner SHALL use the Inventory_Generator output (terraform_hosts.ini) produced by Terraform to target all EC2 instances in the Auto_Scaling_Group
3. THE Ansible_Runner SHALL execute the site.yml playbook against all hosts in the generated inventory
4. THE Ansible_Runner SHALL authenticate to each EC2 instance using the SSH private key retrieved from Secrets_Manager
5. WHILE the Ansible_Runner is executing, THE Pipeline SHALL stream Ansible output to the GitHub Actions workflow log
6. IF the Ansible_Runner fails on any host, THEN THE Pipeline SHALL terminate the workflow with a non-zero exit code and report which host failed
7. WHEN the Ansible_Runner completes successfully, THE Pipeline SHALL confirm that all 2 instances in the Auto_Scaling_Group have been configured

### Requirement 10: Ansible Web Application Stack Installation

**User Story:** As a DevOps engineer, I want Ansible playbooks to install and configure the full web application stack on each EC2 instance, so that the instances are ready to serve WordPress and Python-based web applications.

#### Acceptance Criteria

1. THE Ansible_Runner SHALL install Apache HTTP Server (httpd) on each EC2 instance in the Auto_Scaling_Group
2. THE Ansible_Runner SHALL install PHP and required PHP modules (php, php-mysqlnd, php-fpm, php-json, php-xml) on each EC2 instance
3. THE Ansible_Runner SHALL install WordPress on each EC2 instance and configure it to be served by Apache httpd
4. THE Ansible_Runner SHALL install Python 3 and pip on each EC2 instance
5. THE Ansible_Runner SHALL install MariaDB client packages on each EC2 instance for database connectivity
6. WHEN all packages are installed, THE Ansible_Runner SHALL enable and start the httpd service on each EC2 instance
7. WHEN all packages are installed, THE Ansible_Runner SHALL enable and start the php-fpm service on each EC2 instance
8. IF any package installation fails on an EC2 instance, THEN THE Ansible_Runner SHALL report the failed package and host and terminate with a non-zero exit code

### Requirement 11: SSH Key Handling at Runtime

**User Story:** As a DevOps engineer, I want the SSH private key securely retrieved from AWS Secrets Manager at runtime, so that Ansible can connect to EC2 instances without any credentials stored in GitHub.

#### Acceptance Criteria

1. WHEN the Pipeline has authenticated via OIDC, THE Pipeline SHALL retrieve the SSH private key from Secrets_Manager
2. THE Pipeline SHALL write the SSH private key to a temporary file with permissions set to 0600
3. THE Ansible_Runner SHALL reference the SSH private key file path via the ansible_ssh_private_key_file variable
4. WHEN the workflow completes (success or failure), THE Pipeline SHALL delete the temporary SSH private key file

### Requirement 12: Workflow Triggers and Branch Protection

**User Story:** As a DevOps engineer, I want the pipeline to trigger on the correct events, so that validation runs on PRs and deployment runs on main.

#### Acceptance Criteria

1. THE Pipeline SHALL trigger on pull_request events targeting the main branch for the validate and plan stages
2. THE Pipeline SHALL trigger on push events to the main branch for the apply stage
3. THE Pipeline SHALL trigger on workflow_dispatch events for the destroy stage
4. THE Pipeline SHALL use path filters to only trigger when files in environments/, modules/, or ansible/ directories change

### Requirement 13: Pipeline Configuration via Non-Sensitive Variables

**User Story:** As a DevOps engineer, I want a clear specification of required pipeline configuration values, so that the pipeline can be configured correctly with zero secrets in GitHub.

#### Acceptance Criteria

1. THE Pipeline SHALL read the AWS IAM_Role ARN from a GitHub Actions variable or a hardcoded workflow value (not a GitHub secret)
2. THE Pipeline SHALL read the AWS region from a GitHub Actions variable or default to us-east-1
3. THE Pipeline SHALL read the S3 backend bucket name from GitHub Actions variables or hardcoded workflow values
4. THE Pipeline SHALL read the Secrets_Manager secret names or ARNs from GitHub Actions variables or hardcoded workflow values
5. THE Pipeline SHALL store zero values in GitHub Actions secrets


### Requirement 14: Application Load Balancer Provisioning

**User Story:** As a DevOps engineer, I want Terraform to provision an internet-facing Application Load Balancer in front of the Auto Scaling Group, so that HTTP traffic is distributed across the two WordPress EC2 instances.

#### Acceptance Criteria

1. THE ALB_Module SHALL provision an internet-facing ALB in the public subnets of the configured VPC
2. THE ALB_Module SHALL attach the ALB_Security_Group to the ALB
3. THE ALB_Module SHALL be located in the modules/alb/ directory following the same module structure as other Terraform modules in the project
4. WHEN terraform apply completes, THE ALB SHALL be in an active state and reachable via its DNS name
5. THE ALB_Module SHALL expose outputs for the ALB DNS name, ALB ARN, ALB_Security_Group ID, and Target_Group ARN

### Requirement 15: ALB Security Group Configuration

**User Story:** As a DevOps engineer, I want a dedicated security group for the ALB, so that inbound HTTP traffic from the internet is allowed while all other traffic is denied.

#### Acceptance Criteria

1. THE ALB_Module SHALL provision an ALB_Security_Group in the configured VPC
2. THE ALB_Security_Group SHALL allow inbound TCP traffic on port 80 from 0.0.0.0/0 (all IPv4 addresses)
3. THE ALB_Security_Group SHALL allow all outbound traffic to the VPC CIDR range
4. THE ALB_Security_Group SHALL deny all inbound traffic on ports other than port 80

### Requirement 16: ALB Target Group and Health Checks

**User Story:** As a DevOps engineer, I want a target group with health checks on port 80, so that the ALB only routes traffic to healthy EC2 instances.

#### Acceptance Criteria

1. THE ALB_Module SHALL provision a Target_Group in the configured VPC with protocol HTTP and port 80
2. THE Target_Group SHALL perform HTTP health checks on port 80 using the "/" path
3. THE Target_Group SHALL use a health check interval of 30 seconds, a timeout of 5 seconds, a healthy threshold of 2, and an unhealthy threshold of 3
4. WHEN an EC2 instance fails consecutive health checks, THE Target_Group SHALL mark the instance as unhealthy and stop routing traffic to the instance
5. WHEN an unhealthy EC2 instance passes consecutive health checks, THE Target_Group SHALL mark the instance as healthy and resume routing traffic to the instance

### Requirement 17: ALB HTTP Listener

**User Story:** As a DevOps engineer, I want an HTTP listener on port 80, so that the ALB accepts incoming HTTP requests and forwards them to the target group.

#### Acceptance Criteria

1. THE ALB_Module SHALL provision an HTTP listener on the ALB on port 80
2. THE HTTP listener SHALL forward all incoming requests to the Target_Group as the default action
3. WHEN a request arrives on port 80 of the ALB, THE HTTP listener SHALL route the request to a healthy instance registered in the Target_Group

### Requirement 18: Auto Scaling Group Integration with ALB

**User Story:** As a DevOps engineer, I want the Auto Scaling Group to register its instances with the ALB target group, so that new and existing instances automatically receive traffic through the load balancer.

#### Acceptance Criteria

1. THE Auto_Scaling_Group SHALL reference the Target_Group ARN via the target_group_arns attribute
2. WHEN a new EC2 instance is launched by the Auto_Scaling_Group, THE Auto_Scaling_Group SHALL automatically register the instance with the Target_Group
3. WHEN an EC2 instance is terminated by the Auto_Scaling_Group, THE Auto_Scaling_Group SHALL automatically deregister the instance from the Target_Group
4. THE ALB_Module SHALL pass the Target_Group ARN as an output consumed by the Auto_Scaling_Group module via the environment configuration

### Requirement 19: EC2 Instance Security Group Update for ALB Traffic

**User Story:** As a DevOps engineer, I want the EC2 instance security group to allow inbound HTTP traffic only from the ALB, so that instances are not directly accessible on port 80 from the internet.

#### Acceptance Criteria

1. THE Launch_Template security group SHALL allow inbound TCP traffic on port 80 only from the ALB_Security_Group
2. THE Launch_Template security group SHALL deny inbound TCP traffic on port 80 from sources other than the ALB_Security_Group
3. THE ALB_Module SHALL output the ALB_Security_Group ID so that the EC2 instance security group can reference the ALB_Security_Group as an allowed source
