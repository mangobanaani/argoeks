resource "aws_msk_configuration" "server" {
  name              = "${var.name}-config"
  kafka_versions    = [var.kafka_version]
  server_properties = <<-PROPS
    auto.create.topics.enable = false
    delete.topic.enable = true
    default.replication.factor = 3
    min.insync.replicas = 2
  PROPS
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes
  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids
  }
  encryption_info {
    encryption_at_rest_kms_key_arn = var.encryption_kms_key_arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }
  configuration_info {
    arn      = aws_msk_configuration.server.arn
    revision = aws_msk_configuration.server.latest_revision
  }
  client_authentication {
    unauthenticated = false
    sasl {
      iam = true
    }
  }
  tags = var.tags
}

output "bootstrap_brokers_tls" { value = aws_msk_cluster.this.bootstrap_brokers_tls }
output "arn" { value = aws_msk_cluster.this.arn }
