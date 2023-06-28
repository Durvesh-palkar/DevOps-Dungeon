# This file contains the values for the variables used in the Terraform configuration
# It's recommended to define the variable values in thiss file instead of hardcoding them in the configuration files

# AWS region where the EC2 instance will be launched
region = "us-east-1"

# Amazon Machine Image (AMI) ID for the EC2 instance
ami = "ami-06e46074ae430fba6"

# Instance type for the EC2 instance
instance_type = "t2.micro"

# Name of the Lambda function
function_name = "health_check"

# Slack webhook URL to post messages to Slack channel
slack_webhook_url = ""

# Whether to run Ansible playbook or not
run_ansible_playbook = true