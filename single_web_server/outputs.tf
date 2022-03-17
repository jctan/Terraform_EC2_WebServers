output "public_ip" {
  value       = aws_instance.helloworld.public_ip
  description = "The EC2 Instance Public IP for HTTP request"
}
