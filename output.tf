output "template_id" {
  value = aws_launch_template.this.id
}

output "template_name" {
  value = aws_launch_template.this.name
}

output "asg_id" {
  value = aws_autoscaling_group.this.id
}

output "asg_arn" {
  value = aws_autoscaling_group.this.arn
}


output "asg_name" {
  value = aws_autoscaling_group.this.name
}