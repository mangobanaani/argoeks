resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "memcached" {
  name        = "${var.name}-sg"
  description = "Memcached access"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 11211
    to_port     = 11211
    protocol    = "tcp"
    cidr_blocks = concat([var.vpc_cidr], var.allowed_cidrs)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.name
  engine               = "memcached"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = var.parameter_group_name
  port                 = 11211
  security_group_ids   = [aws_security_group.memcached.id]
  subnet_group_name    = aws_elasticache_subnet_group.this.name
}

output "configuration_endpoint" { value = aws_elasticache_cluster.this.configuration_endpoint }
output "port" { value = 11211 }
output "security_group_id" { value = aws_security_group.memcached.id }
