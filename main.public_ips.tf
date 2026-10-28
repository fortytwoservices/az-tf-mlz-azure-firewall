module "public_ip" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.2"
  for_each = local.created_public_ips

  name                = each.value.name
  parent_id           = var.parent_id
  location            = var.location
  zones               = local.zones
  public_ip_prefix_id = each.value.public_ip_prefix_id
  tags                = var.tags
  resource_types      = var.resource_types.network_public_ip_addresses
  ignore_body_changes = var.ignore_body_changes.network_public_ip_addresses
  retry               = var.retry
  timeouts            = var.timeouts
}

# Azure deletes no public IP address a firewall uses (PublicIPAddressCannotBeDeleted). Terraform destroys a
# removed or renamed address before it updates the firewall, unless the address is create_before_destroy:
# then the firewall moves to the new set first and the old address goes last. A module call cannot set
# that, but Terraform passes create_before_destroy on to whatever a create_before_destroy resource depends
# on; this resource exists for that only. The firewall itself stays destroy-before-create, because its
# subnet holds one firewall. Cost: an address replaced under the same name (a change of `zones`) is created
# while the old one still exists, so it needs a new name.
resource "terraform_data" "public_ip_destroy_order" {
  input = { for name, public_ip in module.public_ip : name => public_ip.resource_id }

  lifecycle {
    create_before_destroy = true
  }
}
