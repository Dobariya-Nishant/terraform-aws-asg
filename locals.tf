locals {
  name    = "${var.name}-${var.environment}"
  image_id = var.ecs_cluster_name != null ? data.aws_ami.al2023_ecs_kernel6plus.image_id : coalesce(var.ami_id, data.aws_ami.al2023_kernel6plus.image_id)
  user_data = var.ecs_cluster_name != null ? data.template_file.ecs_user_data[0].rendered : var.user_data
  key_pair_name = var.create_new_key_pair == true ? aws_key_pair.this[0].key_name : var.key_pair_name

  common_tags = {
    Project     = var.project_name 
    Environment = var.environment
  }
}