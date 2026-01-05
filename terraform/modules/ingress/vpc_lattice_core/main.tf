resource "aws_vpclattice_service_network" "this" {
  name = var.name
  tags = var.tags
}

resource "aws_vpclattice_service_network_vpc_association" "assoc" {
  for_each                   = toset(var.vpc_ids)
  service_network_identifier = aws_vpclattice_service_network.this.id
  vpc_identifier             = each.value
}

output "service_network_id" { value = aws_vpclattice_service_network.this.id }
