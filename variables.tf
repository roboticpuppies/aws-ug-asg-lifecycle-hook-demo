variable "vpc_id" {
  type = string
  description = "The VPC ID to use. Let's use existing VPC for this demo."
}

variable "aws_region" {
  type = string
  description = "The AWS region to use."
}

variable "vpc_zone_identifier" {
  description = "Which subnet to use for the ASG. Let's use existing subnets for this demo."
  type = list(string)
}

variable "base_ami_id" {
  description = "AMI ID to use for the launch template. I use Ubuntu 24.04 x86_64 in Singapore region (ap-southeast-1)."
  type = string
}

variable "sg_ids" {
  description = "Security group IDs to use for the ASG."
  type = list(string)
}

variable "ssh_key_name" {
  description = "SSH key name to use for the ASG. You can create a new SSH key pair in the AWS console and use its name here."
  type = string
}