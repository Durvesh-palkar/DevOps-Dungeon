variable "name" {
  description = "the name of your stack"
}

variable "subnets" {
  description = "List of subnet IDs"
}

variable "ecs_service_security_groups" {
  description = "Comma separated list of security groups"
}

variable "container_port" {
  description = "Port of container"
}

variable "container_cpu" {
  description = "The number of cpu units used by the task"
}

variable "container_mem" {
  description = "The amount (in MiB) of memory used by the task"
}

variable "image_name" {
  description = "Docker image to be launched"
}

variable "image_tag" {
  description = "Image tag to be used"
}

variable "aws_alb_target_group_arn" {
  description = "ARN of the alb target group"
}

variable "service_desired_count" {
  description = "Number of services running in parallel"
}