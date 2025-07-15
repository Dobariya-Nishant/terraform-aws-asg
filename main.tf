# ===========================================================
# 🔍 Fetch public IP of current machine (used for SSH access)
# ===========================================================

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# ===================================
# 🔐 TLS Key Pair Creation (Optional)
# ===================================

resource "tls_private_key" "this" {
  count = var.create_new_key_pair == true ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  count = var.create_new_key_pair == true ? 1 : 0
  key_name   = "${local.name}-key"
  public_key = tls_private_key.this[0].public_key_openssh
}

resource "local_file" "this" {
  count = var.create_new_key_pair == true ? 1 : 0
  filename        = "${path.root}/keys/${aws_key_pair.this[0].key_name}.pem"
  content         = tls_private_key.this[0].private_key_openssh
  file_permission = "0600"
}

# =================================
# 🔒 Security Group + Ingress Rules
# =================================

resource "aws_security_group" "this" {
  description = "Security Group"
  name        = local.name
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = local.name })
}

# Conditional Ingress: HTTP
resource "aws_security_group_rule" "public_http" {
  count = var.enable_public_http == true ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP"
  security_group_id = aws_security_group.this.id
}

# Conditional Ingress: HTTPS
resource "aws_security_group_rule" "public_https" {
  count = var.enable_public_https == true ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS"
  security_group_id = aws_security_group.this.id
}

# Conditional Ingress: SSH only from current IP
resource "aws_security_group_rule" "current_ip_ssh" {
  count = var.enable_ssh_from_current_ip ? 1 : 0
  description       = "Allow SSH"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [data.http.my_ip.response_body]
  security_group_id = aws_security_group.this.id
}

# Conditional Ingress: SSH from anywhere (NOT recommended in prod unless necessary)
resource "aws_security_group_rule" "public_ssh" {
  count = var.enable_public_ssh ? 1 : 0
  description       = "Allow SSH"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

# Allow inbound from load balancer SGs (configurable list)
resource "aws_security_group_rule" "loadbalancer_sg_access" {
  count = length(var.load_balancer_config)
  description              = "Allow HTTPS"
  type                     = "ingress"
  from_port                = var.load_balancer_config[count.index].port
  to_port                  = var.load_balancer_config[count.index].port
  protocol                 = var.load_balancer_config[count.index].protocol
  source_security_group_id = var.load_balancer_config[count.index].sg_id
  security_group_id        = aws_security_group.this.id
}

# Egress rule: Allow all outbound traffic
resource "aws_security_group_rule" "egress" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

# =================================
# 🛡️ IAM Role + Profile for ECS EC2
# =================================

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "ecs_ec2_role_policy" {
  name = "AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role" "this" {
  count = var.ecs_cluster_name != null ? 1 : 0
  name  = "${local.name}-ecsInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "this" {
  count = var.ecs_cluster_name != null ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = data.aws_iam_policy.ecs_ec2_role_policy.arn
}

resource "aws_iam_instance_profile" "this" {
  count = var.ecs_cluster_name != null ? 1 : 0
  name  = "${local.name}-ecsInstanceProfile"
  role  = aws_iam_role.this[0].name
  tags  = merge(local.common_tags, { Name = local.name })
}

# ==============================================
# 🧾 ECS Cluster Registration Script (User Data)
# ==============================================

data "template_file" "ecs_user_data" {
  count = var.ecs_cluster_name != null ? 1 : 0
  template = file("${path.module}/scripts/ecs_cluster_registration.sh.tpl")
  vars = {
    ecs_cluster_name = var.ecs_cluster_name
  }
}

# ==========================================
# 📦 Amazon Linux 2023 AMIs (ECS vs General)
# ==========================================

data "aws_ami" "al2023_ecs_kernel6plus" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-2023*-kernel-6*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "al2023_kernel6plus" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ================================
# 🚀 Launch Template (used by ASG)
# ================================

resource "aws_launch_template" "this" {
  name          = local.name
  instance_type = var.instance_type
  image_id      = local.image_id
  key_name      = local.key_pair_name

  user_data = base64encode(local.user_data)

  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
    }
  }

  dynamic "iam_instance_profile" {
    for_each = var.ecs_cluster_name != null && length(aws_iam_instance_profile.this) > 0 ? [1] : []
    content {
      name = aws_iam_instance_profile.this[0].name
    }
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.ebs_size
      volume_type           = var.ebs_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [aws_security_group.this.id]
  }

  tags = merge(local.common_tags, { Name = local.name })
}

# ==================
# 🧱 Placement Group
# ==================

resource "aws_placement_group" "this" {
  name     = local.name
  strategy = var.placement_strategy
}

# ===========================
# 📈 Auto Scaling Group (ASG)
# ===========================

resource "aws_autoscaling_group" "this" {
  name                      = local.name
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_grace_period = 120
  health_check_type         = var.health_check_type
  placement_group           = aws_placement_group.this.id
  vpc_zone_identifier       = var.vpc_zone_identifier
  protect_from_scale_in     = var.protect_from_scale_in
  target_group_arns         = var.target_group_arns

  metrics_granularity = "1Minute"

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }
}

# =============================================
# 📊 Auto Scaling Policies + Alarms (CPU-based)
# =============================================

resource "aws_autoscaling_policy" "scale_out_cpu" {
  count = var.enable_auto_scaling_alarms ? 1 : 0
  name                   = "scale-out-cpu"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_in_cpu" {
  count = var.enable_auto_scaling_alarms ? 1 : 0
  name                   = "scale-in-cpu"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_out_cpu" {
  count = var.enable_auto_scaling_alarms ? 1 : 0
  alarm_name          = "${local.name}-scale-out"
  alarm_description   = "Scale out when CPU > 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_out_cpu[0].arn]
  tags = merge(local.common_tags, { Name = "${local.name}-scale-out" })
}

resource "aws_cloudwatch_metric_alarm" "scale_in_cpu" {
  count = var.enable_auto_scaling_alarms ? 1 : 0
  alarm_name          = "${local.name}-scale-in"
  alarm_description   = "Scale in when CPU < 60%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_in_cpu[0].arn]
  tags = merge(local.common_tags, { Name = "${local.name}-scale-in" })
}
