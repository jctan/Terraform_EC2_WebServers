# adding a dns name as output makes it easier to test
output "elb_dns_name" {
  value       = aws_elb.helloworld.dns_name
  description = "The domain name of the load balancer"
}