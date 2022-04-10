output "debug" {
  value       = data.aws_availability_zones.available.names
  description = "The names of the available zones in this AWS account for specific region"
}
