################################################################################
# Endpoint(s)
################################################################################

data "aws_vpc_endpoint_service" "this" {
  for_each = var.vpc_endpoints

  service      = lookup(each.value, "service", null)
  service_name = lookup(each.value, "service_name", null)
  filter {
    name   = "service-type"
    values = [lookup(each.value, "service_type", "Interface")]
  }

}

resource "aws_vpc_endpoint" "this" {
  for_each = var.vpc_endpoints

  vpc_id            = var.vpc_id
  service_name      = data.aws_vpc_endpoint_service.this["${each.key}"].service_name
  vpc_endpoint_type = lookup(each.value, "service_type", "Interface")

  subnet_ids          = lookup(each.value, "service_type", "Interface") == "Interface" ? lookup(each.value, "subnet_ids", var.subnet_ids) : null
  private_dns_enabled = lookup(each.value, "service_type", "Interface") == "Interface" ? lookup(each.value, "private_dns_enabled", false) : null
  route_table_ids     = lookup(each.value, "service_type", "Interface") == "Gateway" ? lookup(each.value, "route_table_ids", []) : null
  security_group_ids  = lookup(each.value, "service_type", "Interface") == "Interface" ? lookup(each.value, "security_group_ids", null) : null

}
