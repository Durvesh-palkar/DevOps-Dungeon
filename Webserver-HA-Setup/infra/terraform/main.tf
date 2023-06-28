#################################################
##       NETWORKING
#################################################

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Create public and private subnets in different availability zones
resource "aws_subnet" "public" {
  count             = 1
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index % length(data.aws_availability_zones.available.names))

  tags = {
    Name = "public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = 1
  cidr_block        = "10.0.${count.index + 10}.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index % length(data.aws_availability_zones.available.names))

  tags = {
    Name = "private-${count.index}"
  }
}

# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# Create a route table for the public subnets and associate it with the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public" {
  count          = 1
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


#################################################
##       WEB-SERVER
#################################################

# Fetch your public IP
data "http" "myip" {
  url = "https://checkip.amazonaws.com/"
  # url = "http://ipv4.icanhazip.com"
}

# Create security groups for the instances
resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web"
  }
}

# Create key-pair for the instances
resource "aws_key_pair" "web" {
  key_name   = "web"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

# Create an EC2 instance for the web server
resource "aws_instance" "web" {
  ami                         = var.ami
  associate_public_ip_address = true
  instance_type               = var.instance_type
  # subnet_id                   = element(slice(aws_subnet.public.*.id, 0, length(aws_subnet.public)), count.index % length(aws_subnet.public))
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.web.key_name

  tags = {
    Name = "web"
  }
}

resource "local_file" "ansible_inventory" {
  content = "[webserver]\n${aws_instance.web.public_ip} ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_user=ec2-user ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
  filename = "../ansible/inventory"
}

resource "local_file" "instance_details" {
  # content  = "{\n\"instance_id\": \"${aws_instance.web.id}\",\n \"public_ip\": \"${aws_instance.web.public_ip}\"\n}"
  filename = "${path.module}/instance-details.json"
  content  = <<-EOT
    {
      "instance_id": "${aws_instance.web.id}",
      "public_ip": "${aws_instance.web.public_ip}"
    }
  EOT
}

resource "null_resource" "configure_webserver" {
  count = var.run_ansible_playbook ? 1 : 0

  # triggers = {
  #   timestamp = "${timestamp()}"
  # }
  
  provisioner "local-exec" {
    command = "cd ../ansible && ANSIBLE_FORCE_COLOR=true ansible-playbook -i inventory playbook.yml"
  }

  depends_on = [
    local_file.ansible_inventory,
    local_file.instance_details,
  ]
}

output "show_webpage_url" {
  value = "The webpage can be accessed using: http://${aws_instance.web.public_ip}:80"
}


#################################################
##       HEALTH-CHECK SYSTEM
#################################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.function_name}_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = var.function_name
  path        = "/"
  description = "IAM policy for lambda logging"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "null_resource" "create_zip" {

  triggers = {
    # files = "${join(",", fileset("../../app/health-check/","*"))}"
    # dependencies = "${md5(file("../../app/health-check/requirements.txt"))}"
    # dir_sha1 = sha1(join("", [for f in fileset("../../app/health-check/", "*"): filesha1(f)]))
    requirements = filesha256("../../app/health-check/requirements.txt")
    source_code  = filesha256("../../app/health-check/health-check.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p /tmp/lambda-zip-folder;
      cp ../../app/health-check/health-check.py /tmp/lambda-zip-folder/;
      pip install -r ../../app/health-check/requirements.txt -t /tmp/lambda-zip-folder/;
      cd /tmp/lambda-zip-folder/;
      zip -r ../${var.function_name}.zip .
    EOT
  }
}

# data "archive_file" "lambda_zip_file" {
#   type        = "zip"
#   source_dir  = "/tmp/lambda-zip-folder/"
#   output_path = "/tmp/${var.function_name}.zip"
# }

resource "aws_lambda_function" "health_check" {
  function_name    = var.function_name
  runtime          = "python3.8"
  handler          = "health-check.handler"
  memory_size      = 128
  timeout          = 30
  role             = aws_iam_role.lambda_role.arn
  # source_code_hash = filebase64sha256("../../app/health-check/health-check.py")
  # filename         = "../../app/health-check/health-check.py"
  filename         = "/tmp/${var.function_name}.zip"
  source_code_hash = filebase64sha256("/tmp/${var.function_name}.zip") 
  # source_code_hash = data.archive_file.lambda_zip_file.output_base64sha256
  environment {
    variables = {
      ENDPOINTS_TO_MONITOR = "${aws_instance.web.public_ip}"
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  depends_on = [null_resource.create_zip]

  lifecycle {
    replace_triggered_by = [
      null_resource.create_zip
    ]
  }
}

resource "aws_cloudwatch_event_rule" "health_check_trigger" {
  name                = "health_check_schedule"
  description         = "Scheduled event to trigger the health check Lambda function"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "health_check" {
  target_id = "health_check_lambda_target"
  rule      = aws_cloudwatch_event_rule.health_check_trigger.name
  arn       = aws_lambda_function.health_check.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.health_check_trigger.arn
}