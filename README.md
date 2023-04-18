# Terraform AWS Network and Web Server

This Terraform project creates an AWS VPC with public and private subnets across different availability zones, an internet gateway, a route table, and an EC2 instance acting as a web server.


---

## Usage

1. Clone the repository
2. Update the infra/terraform/config.tfvars file with your desired values
3. Initialize the project:  
```
cd infra/terraform/
terraform init
```
4. Review the execution plan:
```
terraform plan -var-file=config.tfvars
```
5. Apply the changes:
```
terraform apply -var-file=config.tfvars
```
6. To tear down the infrastructure, run:
```
terraform destroy -var-file=config.tfvars
```

## Resources
This Terraform configuration will create the following resources:

- `aws_vpc.main` - The VPC with CIDR block 10.0.0.0/16.
- `aws_subnet.public` - Public subnet across different availability zones.
- `aws_subnet.private` - Private subnet across different availability zones.
- `aws_internet_gateway.main` - Internet Gateway attached to the VPC.
- `aws_route_table.public` - Route Table with default route to the Internet Gateway.
- `aws_security_group.web` - Security group for the web server instance.
- `aws_instance.web` - EC2 instance running as a web server.
- `local_file.ansible_inventory` - A local file containing the inventory for Ansible.
- `local_file.instance_details` - A local file containing the details of the EC2 instance to pass in HTML code.
- `null_resource.configure_webserver` - A null resource that runs an Ansible playbook to configure the web server instance.


## Variables

| Variable Name         | Type   | Default Value                            | Description                                                |
|-----------------------|--------|------------------------------------------|------------------------------------------------------------|
| region                | string | us-east-1                                | AWS region where the EC2 instance will be launched         |
| ami                   | string | ami-06e46074ae430fba6                    | Amazon Machine Image (AMI) ID for the EC2 instance         |
| instance_type         | string | t2.micro                                 | Instance type for the EC2 instance                         |
| function_name         | string | my_lambda_function                       | Name of the Lambda function                                |
| slack_webhook_url     | string | https://hooks.slack.com/services/foo/bar | Slack webhook URL to post messages to Slack channel        |
| run_ansible_playbook  | bool   | false                                    | Whether to run Ansible playbook or not                     |


## Outputs

| Name              | Description                   |
|-------------------|-------------------------------|
| show_webpage_url  | URL to access the web server  |