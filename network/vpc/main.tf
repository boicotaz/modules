data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    { "Name" = var.name },
    var.tags,
  )

}

resource "aws_default_security_group" "main" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      self            = lookup(ingress.value, "self", null)
      protocol        = lookup(ingress.value, "protocol", -1)
      from_port       = lookup(ingress.value, "from_port", 0)
      to_port         = lookup(ingress.value, "to_port", 0)
      cidr_blocks     = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
      security_groups = compact(split(",", lookup(ingress.value, "security_groups", "")))
      description     = lookup(ingress.value, "description", "")
    }
  }

  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      self            = lookup(egress.value, "self", null)
      protocol        = lookup(egress.value, "protocol", -1)
      from_port       = lookup(egress.value, "from_port", 0)
      to_port         = lookup(egress.value, "to_port", 0)
      cidr_blocks     = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
      security_groups = compact(split(",", lookup(egress.value, "security_groups", "")))
      description     = lookup(egress.value, "description", "")
    }
  }

  tags = merge(
    { "Name" = var.name },
    var.tags,
  )
}
resource "aws_vpc_ipv4_cidr_block_association" "main" {
  #count = local.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0
  count = length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.main.id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "main" {
  count = var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    { "Name" = var.name },
    var.tags
  )
}


################################################################################
# Publiс routes
################################################################################

resource "aws_route_table" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    { "Name" = "${var.name}-${var.public_subnet_suffix}" },
    var.tags
  )
}

resource "aws_route" "public_internet_gateway" {
  count = var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id

  timeouts {
    create = "5m"
  }
}
