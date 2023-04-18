variable "region" {
  default = "us-east-1"
}

variable "ami" {
  default = "ami-06e46074ae430fba6"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "function_name" {
  default = "my_lambda_function"
}

variable "slack_webhook_url" {
  default = "https://hooks.slack.com/services/foo/bar"
}

variable "run_ansible_playbook" {
  default = false
}