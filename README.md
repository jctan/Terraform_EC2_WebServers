# Terraform EC2 Instance Web Servers

1. Single Web Server: Deploy a single EC2 instance with a web server that returns "Hello, World" for every request on port 8080.

2. Cluster of Web Servers: Deploy a cluster of EC2 instance in an Auto Scaling Group (ASG) and an Elastic Load Balancer (ELB). The ELB listens to port 80 and distributes load across the EC2 instances, each of which runs the same "Hello, World" web server.