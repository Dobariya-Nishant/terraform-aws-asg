variable "project_name" {
  description = "Name of the overall project. Used for consistent tagging and naming."
  type        = string
}

variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}







variable "ami_id" {
  description = "AMI ID for instances"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ebs_type" {
  description = "EBS volume type attached to EC2 instances (e.g., gp2, gp3, io1)."
  type        = string
  default     = "gp2"
}

variable "ebs_size" {
  description = "Size of the EBS volume (in GB) attached to the EC2 instance."
  type        = string
  default     = 30
}

variable "use_spot" {
  description = "Set to true to use EC2 Spot Instances instead of On-Demand."
  type        = bool
  default     = false
}

variable "key_pair_name" {
  description = "Optional: Name of an existing EC2 key pair to use. If not provided, a new one will be created."
  type        = string
  default     = null
}

variable "create_new_key_pair" {
  description = "Whether to enable CloudWatch alarms for scaling EC2 instances in/out."
  type        = bool
  default     = false
}

variable "associate_public_ip_address" {
  description = "Whether to enable CloudWatch alarms for scaling EC2 instances in/out."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "The Base64-encoded user data to provide when launching the instance"
  type        = string
  default     = null
}

variable "security_groups" {
  description = "A list of security group IDs to associate"
  type        = list(string)
  default     = []
}




variable "ecs_cluster_name" {
  description = "ECS cluster name. Used to determine whether to use ECS-specific AMI and user data."
  type        = string
  default     = null
}




variable "desired_capacity" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "min_size" {
  type    = number
  default = 1
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs"
}

variable "placement_strategy" {
  description = "Placement strategy for EC2 instances. (e.g., spread, cluster)"
  type        = string
  default     = "spread"
}

variable "health_check_type" {
  description = "Type of health check for Auto Scaling Group (EC2 or ELB)."
  type        = string
  default     = "EC2"
}

variable "target_group_arns" {
  description = "List of target group ARNs for registering EC2 instances (used with ALB/NLB)."
  type        = list(string)
  default     = []
}

variable "protect_from_scale_in" {
  description = "Allows setting instance protection. The autoscaling group will not select instances with this setting for termination during scale in events."
  type        = bool
  default     = false
}

variable "enable_auto_scaling_alarms" {
  description = "Whether to enable CloudWatch alarms for scaling EC2 instances in/out."
  type        = bool
  default     = false
}

variable "vpc_zone_identifier" {
  description = "A list of subnet IDs to launch resources in. Subnets automatically determine which availability zones the group will reside. Conflicts with `availability_zones`"
  type        = list(string)
  default     = null
}



