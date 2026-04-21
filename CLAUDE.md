# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This is a Terraform demo project for an AWS User Group presentation. Its goal is to demonstrate how ASG lifecycle hooks can improve reliability by **preventing EC2 instances from being registered to an ALB Target Group before they are healthy and ready** — and similarly holding terminating instances until in-flight requests are drained.

## Commands

```bash
terraform init      # Initialize working directory and download providers/modules
terraform validate  # Validate configuration syntax
terraform fmt       # Format all .tf files
terraform plan      # Preview changes
terraform apply     # Create/update infrastructure
terraform destroy   # Tear down all managed resources
```

## Architecture

```
ASG (example-web-server, desired=0)
 ├── Launch Template
 │    ├── Ubuntu 24.04, t3.micro, spot enabled
 │    ├── IMDSv2 enforced (single hop, tokens required)
 │    ├── EBS gp3 8GB (encrypted)
 │    └── User data: installs nginx + aws-cli, downloads /root/complete-lifecycle-action.sh
 ├── Lifecycle Hooks (1-hour timeout, default result: ABANDON)
 │    ├── Launch hook  → instance paused in Pending:Wait until script completes action
 │    └── Terminate hook → instance paused in Terminating:Wait for graceful drain
 ├── IAM Instance Profile
 │    └── Policy: CompleteLifecycleAction, DescribeAutoScalingInstances, DescribeLifecycleHooks
 └── ALB Target Group (HTTP :80)
```

**Key design point**: With `default_result = ABANDON`, if the lifecycle action is not completed within 3600 seconds, the instance is terminated rather than being allowed to join the target group in an unready state.

## How to Run the Demo

1. Update [terraform.tfvars](terraform.tfvars) with your own AWS resource IDs (VPC, subnet, AMI, SG, key pair)
2. `terraform apply`
3. Scale ASG desired capacity to 1 (via console or `aws autoscaling set-desired-capacity`)
4. SSH into the instance — it will be in `Pending:Wait` (not yet serving traffic)
5. Run `/root/complete-lifecycle-action.sh` to signal readiness
6. Instance moves to `InService` and registers with the ALB target group
7. Scale down to trigger the terminate hook; observe `Terminating:Wait` state

The script uses IMDSv2 to retrieve `instance-id`, `region`, and the ASG name, then calls `aws autoscaling complete-lifecycle-action`.

## Conventions

- **Naming**: `example-web-server` prefix for ASG/TG; `example-iam-for-lifecycle-hook-demo` for IAM role
- **Tagging**: All resources carry `Project = "AWS-UG-ASG-Lifecycle-Hook-Demo"`, `ManagedBy = "Terraform"`, `Environment = "Development"`
- **IAM path**: `/ec2/`
- **tfvars**: `.gitignore` excludes `*.tfvars` — the committed [terraform.tfvars](terraform.tfvars) is an example only; keep real values local

## Pitfalls

- ASG starts with `desired_capacity = 0`; manually scale up to test hooks
- User data downloads the lifecycle script from GitHub — the instance needs outbound internet access
- The lifecycle hook timeout is 3600 seconds; complete the action before it expires or the instance is abandoned
- Do not run `terraform apply` with a non-zero desired capacity unless you intend to incur EC2 costs
