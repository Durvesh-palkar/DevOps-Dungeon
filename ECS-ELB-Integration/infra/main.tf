provider "aws" {
  region  = var.region
}

terraform {
  backend "s3" {
    bucket  = "demo--terraform-backend-store"
    encrypt = true
    key     = "terraform.tfstate"
    region  = "us-east-1"
  }
}

module "networking" {
  source             = "./networking"
  name               = var.name
  cidr               = var.cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  availability_zones = var.availability_zones
  container_port     = var.container_port
}

module "alb" {
  source              = "./elb"
  name                = var.name
  vpc_id              = module.networking.id
  subnets             = module.networking.public_subnets
  alb_security_groups = [module.networking.alb]
  health_check_path   = var.health_check_path
}

module "ecs" {
  source                      = "./ecs"
  name                        = var.name
  subnets                     = module.networking.private_subnets
  aws_alb_target_group_arn    = module.alb.aws_alb_target_group_arn
  ecs_service_security_groups = [module.networking.ecs_tasks]
  container_port              = var.container_port
  container_cpu               = var.container_cpu
  container_mem            = var.container_mem
  service_desired_count       = var.service_desired_count
  image_name                  = "demo"
  image_tag                   = var.image_tag
}

