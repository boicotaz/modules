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
# NAT Gateway
################################################################################

resource "aws_nat_gateway" "this" {
  count = var.create_ngw && length(var.private_subnets) > 0 ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    { "Name" = var.name },
    var.tags
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "nat" {
  count = var.create_ngw && length(var.private_subnets) > 0 ? 1 : 0

  vpc = true
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

################################################################################
# Private routes
################################################################################

resource "aws_route_table" "private" {
  count = length(var.private_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    { "Name" = "${var.name}-${var.private_subnet_suffix}" },
    var.tags
  )
}

resource "aws_route" "public_nat_gateway" {
  count = var.create_ngw && length(var.private_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}
################################################################################
# Public subnet
################################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(concat(var.public_subnets, [""]), count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.public_subnet_suffix}-%s",
        element(data.aws_availability_zones.available.names, count.index),
      )
    },
    var.tags
  )
}

################################################################################
# Private subnet
################################################################################

resource "aws_subnet" "private" {
  count = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = element(concat(var.private_subnets, [""]), count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(
    {
      "Name" = format(
        "${var.name}-${var.private_subnet_suffix}-%s",
        element(data.aws_availability_zones.available.names, count.index),
      )
    },
    var.tags
  )
}
################################################################################
# Route table association
################################################################################

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private[0].id
}
