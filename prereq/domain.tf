provider "aws" {}

resource "aws_route53_zone" "main" {
  name = var.domain
  tags = var.tags
}

output "name_servers" {
    value = aws_route53_zone.main.name_servers
    description = "Set those name servers on your domain"
}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}