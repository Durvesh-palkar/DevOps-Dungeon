resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecsTaskExecutionRole"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "main" {
  name               = "${var.name}-cluster"
  capacity_providers = ["FARGATE_SPOT"]
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name}-task-df"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  container_definitions = jsonencode(
    [
      {
        name      = "${var.name}-container"
        image     = "${aws_ecr_repository.main.repository_url}:${var.image_tag}"
        essential = true
        portMappings = [{
          protocol      = "tcp"
          containerPort = var.container_port
          hostPort      = var.container_port
        }]
      }
    ]
  )
}

resource "aws_ecs_service" "main" {
  name                = "${var.name}-service"
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.main.arn
  desired_count       = var.service_desired_count
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  network_configuration {
    security_groups  = var.ecs_service_security_groups
    subnets          = var.subnets.*.id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.aws_alb_target_group_arn
    container_name   = "${var.name}-container"
    container_port   = var.container_port
  }
}

resource "aws_ecr_repository" "main" {
  name                 = "${var.name}-ecr-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

output "aws_ecr_repository_url" {
  value = aws_ecr_repository.main.repository_url
}