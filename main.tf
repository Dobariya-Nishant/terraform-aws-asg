


resource "tls_private_key" "this" {
  count = var.create_new_key_pair == true ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  count = var.create_new_key_pair == true ? 1 : 0

  key_name   = "${local.name}-key"
  public_key = tls_private_key.this[0].public_key_openssh
}

resource "local_file" "private_key_file" {
  count = var.create_new_key_pair == true ? 1 : 0

  filename        = "${path.root}/keys/${aws_key_pair.generated_key[0].key_name}.pem"
  content         = tls_private_key.this[0].private_key_openssh
  file_permission = "0600"
}








resource "aws_iam_role" "ecs_instance_role" {
  count = var.ecs_cluster_name != null ? 1 : 0


  name               = "${local.name}-ecsInstanceRole" 
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attach" {
  count = var.ecs_cluster_name != null ? 1 : 0

  role       = aws_iam_role.ecs_instance_role[0].name
  policy_arn = data.aws_iam_policy.ecs_ec2_role_policy.arn
}

resource "aws_iam_instance_profile" "ecs_profile" {
  count = var.ecs_cluster_name != null ? 1 : 0

  name = "${local.name}-ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role[0].name
}





data "template_file" "ecs_user_data" {
  count = var.ecs_cluster_name != null ? 1 : 0
  template = file("${path.module}/scripts/ecs_cluster_registration.sh.tpl")

  vars = {
    ecs_cluster_name = var.ecs_cluster_name
  }
}





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
    for_each = var.ecs_cluster_name != null && length(aws_iam_instance_profile.ecs_profile) > 0 ? [1] : []
    content {
      name = aws_iam_instance_profile.ecs_profile[0].name
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
    security_groups             = var.security_groups
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.name
    }
  )
}






resource "aws_placement_group" "this" {
  name     = local.name  
  strategy = var.placement_strategy
}

resource "aws_autoscaling_group" "this" {
  name                      = local.name
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_grace_period = 120
  health_check_type         = var.health_check_type
  placement_group           = aws_placement_group.this.id
  vpc_zone_identifier       = var.vpc_zone_identifier
  protect_from_scale_in = var.protect_from_scale_in

  target_group_arns = var.target_group_arns

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







resource "aws_autoscaling_policy" "scale_out_cpu" {
  count = var.enable_auto_scaling_alarms == true ? 1 : 0

  name                   = "scale-out-cpu"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.multi_az_group.name
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_in_cpu" {
  count = var.enable_auto_scaling_alarms == true ? 1 : 0

  name                   = "scale-in-cpu"
  scaling_adjustment     = "-1"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_out_cpu" {
  count = var.enable_auto_scaling_alarms == true ? 1 : 0

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
    AutoScalingGroupName = aws_autoscaling_group.multi_az_group.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_out_cpu[0].arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-scale-out"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "scale_in_cpu" {
  count = var.enable_auto_scaling_alarms == true ? 1 : 0

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
    AutoScalingGroupName = aws_autoscaling_group.multi_az_group.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_in_cpu[0].arn]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-scale-in" 
    }
  )
}


