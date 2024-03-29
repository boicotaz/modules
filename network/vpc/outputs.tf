output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(aws_vpc.main.id, "")
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = try(aws_vpc.main.arn, "")
}

output "default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation"
  value       = try(aws_vpc.main.default_security_group_id, "")
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = aws_subnet.public[*].arn
}

output "private_route_table_id" {
  description = "The ID of the route table used in private subnets"
  value       = try(aws_route_table.private[0].id, null)
}
