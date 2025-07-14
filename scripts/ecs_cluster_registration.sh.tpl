#!/bin/bash
set -xe


sudo dnf upgrade --refresh -y

# Set your ECS cluster name here:
echo 'ECS_CLUSTER=${ecs_cluster_name}' | sudo tee -a /etc/ecs/ecs.config > /dev/null

# Enable and start the ECS agent service
sudo systemctl enable --now --no-block ecs.service