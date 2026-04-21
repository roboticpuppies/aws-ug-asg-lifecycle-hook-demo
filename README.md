# AWS ASG Lifecycle Hook Demo

Goal: Don't add the instance to a ALB if not ready or healthy.

That is one of the lifecycle hook function.

## Problem

ASG launch instance. Instance not done booting. ALB send traffic. Traffic die. Bad.

## Solution

Lifecycle hook pause instance. Instance boot. Instance run script. Script say "me ready". Instance join ALB. Traffic live. Good.

## What Inside

- Terraform make ASG
- ASG have lifecycle hook
- Hook pause instance in `Pending:Wait`
- User data install nginx, download script
- You SSH, run script, instance join ALB
- Scale down, hook pause again in `Terminating:Wait`

## How Use

1. Put your AWS IDs in `terraform.tfvars`
2. `terraform init`
3. `terraform apply`
4. Scale ASG to 1
5. SSH to instance
6. Run `/root/complete-lifecycle-action.sh`
7. Instance now in ALB. Happy.

## Example

New instance launch. Hook catch it. Instance stuck in `Pending:Wait`. Not in ALB yet.

```
Instance state: Pending:Wait
ALB target:     unused
```

You SSH. You run script. Script talk to AWS.

```bash
/root/complete-lifecycle-action.sh
# Script get token from IMDSv2
# Script get instance-id, region, ASG name
# Script call: aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE
```

Hook receive CONTINUE. Instance move to `InService`. ALB register instance. Traffic flow.

```
Instance state: InService
ALB target:     healthy
```

You scale down later. Terminate hook catch instance. Instance stuck in `Terminating:Wait`. You drain. You complete. Instance die clean.

## Important

- ASG start at 0. You scale up yourself.
- Script download from internet. Instance need internet.
- Timeout 1 hour. Run script before timeout or instance die.
- Default result `ABANDON`. Miss deadline = instance gone.
