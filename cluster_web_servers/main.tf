# -------------------------------------------------------------------------------------
# a single server is a single point of failure, so solution is to run a cluster of servers,
# routing around servers that go down, and adjusting the size of the cluster up or down based on traffic
# by using ASG to auto launch a cluster of ec2 instances, monitor their health, auto restart failed nodes, 
# and adjust size of their cluster in response to demand
# -------------------------------------------------------------------------------------

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
# get a list of all AZ in current region
# queries AWS to fetch the list for current account and region
data "aws_availability_zones" "all" {}

# create launch config that defines each ec2 instance in the auto scaling group (ASG)
# this specify how to configure each ec2 instance in the ASG
# -------------------------------------------------------------------------------------

resource "aws_launch_configuration" "helloworld" {
  image_id = "ami-033b95fb8079dc481"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  # when using a launch configuration with an auto scaling group, you must set create_before_destroy = true.
  # create_before_destroy controls the order in which resources are recreated.
  # default is delete the old one and create the new one. setting to true reverse the order. 
  # this will create the repliacement first, then delete the old one.
  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------------------------------------------------------------------
# create auto scaling group
# ASG will run between 2 - 10 ec2 instances
# need availability_zone to specify which AZ the ec2 instance should be deployed
# use the data source to get the list of subnets in your AWS account.
# -------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "helloworld" {
  launch_configuration = aws_launch_configuration.helloworld.id
  availability_zones   = data.aws_availability_zones.all.names

  min_size = 2
  max_size = 10

  # how does CLB know which ec2 instances to send requests to?
  # use load_balancer param to tell the AWS to register each ec2 instance in CLB
  load_balancers    = [aws_elb.helloworld.name]
  # instances will replace if they're down or stopped because they ran out of memeory or critical process crashed
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg-helloworld"
    propagate_at_launch = true
  }
}

# -------------------------------------------------------------------------------------
# create security group that applies to each ec2 instance in auto scaling group (ASG)
# -------------------------------------------------------------------------------------
resource "aws_security_group" "instance" {
  name = "terraform-helloworld-instance"

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------------------------------------------------------------
# AWS has 3 types of Load Balancer
# Application Load Balancer (ALB): best suited for HTTP and HTTPS traffic.
# Network Load Balancer (NLB): best suited for TCP and UDP traffic.
# Classic Load Balancer (CLB): this is the “legacy” load balancer that predates both the ALB and NLB. It can do HTTP, # HTTPS, and TCP, but offers far fewer features than the ALB or NLB.

# you can deploy your ASG, but a small problem arise that each of multiple servers
# have its own IP address but only want to give end users a single IP to use.
# solution: deploy a load balancer to distribute traffic across servers and give 
# all your users the IP (specifically DNS names) of the load balancer
# deploy a load balancer - create an ELB to route traffic across the auto scaling group
# ALB is best fit but since it uses HTTP but to make it easier with less config, we go with CLB
# create CLB using aws_elb_resource (ELB to let AWS take care of it)
# -------------------------------------------------------------------------------------

resource "aws_elb" "helloworld" {
  name               = "terraform-asg-helloworld"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names

  # can periodically check health of ec2 instance and if instance is unhealthy,
  # it will auto stop routing traffic
  # add HTTP health check where CLB send HTTP requests every 30 sec to the url of each ec2 instance
  # and mark an instance as healthy if it respond with 200
  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

# -------------------------------------------------------------------------------------
# CLB doesn't allow any incoming or outgoing traffic by default so you need security group
# to explicitly allow inbound requests on port 80 and all outbound requests
# create security group that controls the kind of traffic going in and out of the ELB 
# -------------------------------------------------------------------------------------
resource "aws_security_group" "elb" {
  name = "terraform-helloworld-elb"

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
