# ==========================
# Core Project Configuration
# ==========================

variable "project_name" {
  description = "Name of the overall project. Used for consistent naming and tagging across all resources."
  type        = string
}

variable "name" {
  description = "Base name used as an identifier for all resources (e.g., key name, launch template name, etc.)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod). Used for tagging and naming consistency."
  type        = string
}

# ==========
# Networking
# ==========

variable "vpc_id" {
  description = "The VPC ID where resources like EC2, security groups, etc. will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where EC2 instances will be launched."
  type        = list(string)
}

variable "vpc_zone_identifier" {
  description = "List of subnet IDs for the Auto Scaling Group to launch instances in. Determines availability zones."
  type        = list(string)
}

# ====================
# Security Group Rules
# ====================

variable "enable_public_https" {
  description = "Allow inbound traffic on port 443 (HTTPS) from the internet."
  type        = bool
  default     = false
}

variable "enable_public_http" {
  description = "Allow inbound traffic on port 80 (HTTP) from the internet."
  type        = bool
  default     = false
}

variable "enable_public_ssh" {
  description = "Allow inbound SSH access (port 22) from any IP (0.0.0.0/0). Use with caution in production."
  type        = bool
  default     = false
}

variable "enable_ssh_from_current_ip" {
  description = "Allow SSH access (port 22) only from your current public IP."
  type        = bool
  default     = false
}

variable "load_balancer_config" {
  description = "List of objects that define load balancer security group access (used to allow internal traffic from ALB/NLB)."
  type = list(object({
    sg_id    = string
    port     = number
    protocol = optional(string)
  }))
  default = []
}

variable "security_groups" {
  description = "Optional list of additional security group IDs to associate with the EC2 instances."
  type        = list(string)
  default     = []
}

# =======================
# EC2 & AMI Configuration
# =======================

variable "ami_id" {
  description = "AMI ID to use for EC2 instances. If not provided, the latest Amazon Linux 2023 will be used."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type to launch (e.g., t3.micro, m5.large)."
  type        = string
  default     = "t2.micro"
}

variable "ebs_type" {
  description = "EBS volume type (e.g., gp2, gp3, io1) attached to EC2 instances."
  type        = string
  default     = "gp2"
}

variable "ebs_size" {
  description = "Size (in GB) of the root EBS volume attached to EC2 instances."
  type        = string
  default     = 30
}

variable "use_spot" {
  description = "Use EC2 Spot Instances for cost optimization. Set to true to enable."
  type        = bool
  default     = false
}

variable "associate_public_ip_address" {
  description = "Associate a public IP address with launched EC2 instances. Useful for SSH or internet access."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Base64-encoded user data script to bootstrap EC2 instances (e.g., install packages, join ECS cluster)."
  type        = string
  default     = ""
}

# ===================
# Key Pair Management
# ===================

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair to use. If not provided, a new key pair will be created."
  type        = string
  default     = null
}

variable "create_new_key_pair" {
  description = "Set to true to automatically create a new EC2 key pair and store it locally."
  type        = bool
  default     = false
}

# ===============
# ECS Integration
# ===============

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to register the EC2 instances to. If set, ECS-specific AMI and user data will be used."
  type        = string
  default     = null
}

# ==================
# Auto Scaling Group
# ==================

variable "desired_capacity" {
  description = "Number of instances the Auto Scaling Group should launch initially."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances the Auto Scaling Group can scale up to."
  type        = number
  default     = 8
}

variable "min_size" {
  description = "Minimum number of instances the Auto Scaling Group should maintain."
  type        = number
  default     = 1
}

variable "placement_strategy" {
  description = "Placement strategy for EC2 instances within the Auto Scaling Group (e.g., cluster, spread)."
  type        = string
  default     = "spread"
}

variable "health_check_type" {
  description = "Health check type for the Auto Scaling Group. Valid values: 'EC2', 'ELB'."
  type        = string
  default     = "EC2"
}

variable "target_group_arns" {
  description = "List of target group ARNs to register EC2 instances (used when attached to a Load Balancer)."
  type        = list(string)
  default     = []
}

variable "protect_from_scale_in" {
  description = "Protect EC2 instances from being terminated during scale-in events."
  type        = bool
  default     = false
}

# ================================
# CloudWatch Alarms (Auto Scaling)
# ================================

variable "enable_auto_scaling_alarms" {
  description = "Enable CloudWatch alarms that trigger auto scaling based on CPU utilization."
  type        = bool
  default     = false
}
