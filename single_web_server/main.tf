# run a simple "hello world" web server on a single EC2 instance

terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# config aws connection
provider "aws" {
	access_key = "ENTER ACCESS KEY"
	secret_key = "ENTER SECRET KEY"
	region = "us-east-1"
}

# -------------------------------------------------------------------------------------
# use aws instance resource to deploy an ec2 instance
# resource "<PROVIDER>_<TYPE>" "<NAME>" {
# [CONFIG …]
# }

# ami - to run on the ec2 instance
# instance_type - the type of ec2 instance to run

# run web server on port 8080 using busybox (default on ubuntu)
# nohup to ensure the web server keeps running even after this script exists 
# & at the end so the web server runs in a background process and the script can exit
#<<-EOF EOF: terraform syntax that allows multiline strings without \n all over the place

# <PROVIDER>_<TYPE>.<NAME>.<ATTRIBUTE> - aws_security_group.instance.id
# -------------------------------------------------------------------------------------

resource "aws_instance" "helloworld" {
  ami           = "ami-033b95fb8079dc481"
  instance_type = "t2.micro"
  subnet_id = "ENTER SUBNET ID"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  tags = {
    Name = "terraform-helloworld"
  }
}


# -------------------------------------------------------------------------------------
# by default, AWS does not allow any incoming and outgoing traffic from an ec2 instance
# to allow ec2 instance to receive traffic on port 8080, you need to apply security group

# CIDR block of 10.0.0.0/24 represents all IP addresses between 10.0.0.0 and 10.0.0.255. 
# The CIDR block 0.0.0.0/0 is an IP address range that includes all possible IP addresses
# so this security group allows incoming requests on port 8080 from any IP
# -------------------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}