locals {
  user_data = <<-EOT
    #!/bin/bash
    
    # Install NGINX just for the meme
    apt update
    apt install nginx curl -y
    systemctl start nginx
    systemctl enable nginx
    
    # Install AWS CLI
    snap install aws-cli --classic
    
    # Download the script to complete lifecycle action from GitHub repository
    # but don't execute it yet, we will execute it manually later for demo purposes.
    curl -sS https: //raw.githubusercontent.com/roboticpuppies/aws-ug-asg-lifecycle-hook-demo/refs/heads/main/scripts/complete-lifecycle-action.sh -o /root/complete-lifecycle-action.sh
    chmod +x /root/complete-lifecycle-action.sh
  EOT
}

data "aws_iam_policy_document" "asg_lifecycle_hook_policy" {
  statement {
    # Allow the instances to complete lifecycle
    actions   = [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLifecycleHooks"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "asg_lifecycle_hook_policy" {
  name        = "ASGLifecycleHookPolicy"
  description = "IAM policy for ASG lifecycle hook demo"
  policy      = data.aws_iam_policy_document.asg_lifecycle_hook_policy.json
}

resource "aws_alb_target_group" "example_target_group" {
  name     = "example-web-server-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.2.0"

  # Autoscaling group
  name            = "example-web-server"

  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 0
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.vpc_zone_identifier

  initial_lifecycle_hooks = [
    {
      name                 = "LifecycleHookWhenLaunching"
      default_result       = "ABANDON"
      heartbeat_timeout    = 3600
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    },
    {
      name                 = "LifecycleHookWhenTerminating"
      default_result       = "ABANDON"
      heartbeat_timeout    = 3600
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    }
  ]

  # Launch template
  launch_template_name            = "example-web-server-lt"
  launch_template_use_name_prefix = false
  launch_template_description     = "Example launch template for ASG lifecycle hook demo"
  update_default_version          = true

  image_id      = var.base_ami_id
  instance_type = "t3.micro"
  key_name      = var.ssh_key_name
  # IAM role & instance profile
  create_iam_instance_profile = true
  iam_role_name               = "example-iam-for-lifecycle-hook-demo"
  iam_role_path               = "/ec2/"
  iam_role_description        = "IAM role for ASG lifecycle hook demo"
  iam_role_tags               = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    CustomASGLifecycleHookPolicy = aws_iam_policy.asg_lifecycle_hook_policy.arn
  }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/sda1"
      ebs         = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp3"
      }
    }
  ]

  instance_market_options = {
    market_type = "spot"
  }

  # This will ensure imdsv2 is enabled, required, and a single hop which is aws security
  # best practices
  # See https:   //docs.aws.amazon.com/securityhub/latest/userguide/autoscaling-controls.html#autoscaling-4
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = var.sg_ids
      subnet_id             = var.vpc_zone_identifier[0]
    }
  ]

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { Project = "AWS-UG-ASG-Lifecycle-Hook-Demo" }
    },
    {
      resource_type = "volume"
      tags          = { Project = "AWS-UG-ASG-Lifecycle-Hook-Demo" }
    },
    {
      resource_type = "spot-instances-request"
      tags          = { Project = "AWS-UG-ASG-Lifecycle-Hook-Demo" }
    }
  ]

  # Traffic source attachment
  traffic_source_attachments = {
    example-tg = {
      traffic_source_identifier = aws_alb_target_group.example_target_group.arn
      traffic_source_type       = "elbv2" # default
    }
  }
  user_data = base64encode(local.user_data)
}