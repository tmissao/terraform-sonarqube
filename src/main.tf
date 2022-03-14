resource "azurerm_resource_group" "this" {
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet.address_space
  tags              = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.vnet.subnets
  name = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_space
}

resource "azurerm_network_security_group" "this" {
  for_each = var.vnet.subnets
  name                = azurerm_subnet.this[each.key].name
  location            = azurerm_resource_group.this.location
  resource_group_name =  azurerm_resource_group.this.name
  tags              = local.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each                    = local.network_security_rules
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.vnet.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_public_ip" "sonarqube" {
  name = var.vm_sonarqube.name
  location =  azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method = "Static"
  tags              = local.tags
}

resource "azurerm_network_interface" "sonarqube" {
  name = var.vm_sonarqube.name
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  ip_configuration {
    name = var.vm_sonarqube.name
    subnet_id = azurerm_subnet.this[var.vm_sonarqube.subnet].id
    public_ip_address_id = azurerm_public_ip.sonarqube.id
    private_ip_address_allocation = "Dynamic"
  }
  tags              = local.tags
}

data "template_cloudinit_config" "sonarqube" {
    gzip = true
    base64_encode = true

    part {
        filename = "init.cfg"
        content_type = "text/cloud-config"
        content = templatefile("${path.module}/scripts/init.cfg", {
          DISK_LUN = "lun${var.vm_sonarqube.external_disk.lun}"
        })
    }

    part {
        content_type = "text/x-shellscript"
        content = templatefile("${path.module}/templates/setup_sh.tftpl", {
          USER = var.vm_sonarqube.user
          SONAR_JDBC_URL = local.database_jdbc
          SONAR_JDBC_USERNAME = local.database_username
          SONAR_JDBC_PASSWORD = random_password.postgresql_server_database.result
          SONARQUBE_IMAGE = var.sonarqube_docker_image
          NGINX_IMAGE = var.nginx_docker_image
          NGINX_SSL_PRIVATE_KEY = base64encode(local.nginx_ssl_private_key)
          NGINX_SSL_PUBLIC_KEY = base64encode(local.nginx_ssl_public_key)
          NGINX_CONF = base64encode(templatefile(local.nginx_conf_file, {
            NGINX_SERVER_NAME = local.sonarqube_address
          }))
        })
    }
}

resource "azurerm_linux_virtual_machine" "sonarqube" {
  name = var.vm_sonarqube.name
  admin_username = var.vm_sonarqube.user
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  network_interface_ids = [azurerm_network_interface.sonarqube.id]
  size = var.vm_sonarqube.size
  custom_data = data.template_cloudinit_config.sonarqube.rendered
  source_image_reference {
    publisher = var.vm_sonarqube.source_image_reference.publisher
    offer     = var.vm_sonarqube.source_image_reference.offer
    sku       = var.vm_sonarqube.source_image_reference.sku
    version   = var.vm_sonarqube.source_image_reference.version
  }
  os_disk {
    caching = var.vm_sonarqube.os_disk.caching
    storage_account_type = var.vm_sonarqube.os_disk.storage_account_type
    disk_size_gb = var.vm_sonarqube.os_disk.disk_size_gb
  }
  admin_ssh_key {
    username   = var.vm_sonarqube.user
    public_key = file(var.vm_sonarqube.ssh.public_key_path)
  }
  tags              = local.tags
}

resource "azurerm_managed_disk" "sonarqube" {
  name                 = var.vm_sonarqube.name
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  storage_account_type = var.vm_sonarqube.external_disk.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.vm_sonarqube.external_disk.disk_size_gb
  tags              = local.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "sonarqube" {
  managed_disk_id    = azurerm_managed_disk.sonarqube.id
  virtual_machine_id = azurerm_linux_virtual_machine.sonarqube.id
  lun                = var.vm_sonarqube.external_disk.lun
  caching            = var.vm_sonarqube.external_disk.caching
}

resource "random_password" "postgresql_server_database" {
  length           = 32
  special          = true
  override_special = "!@#%*()-_[]{}<>?"
}

resource "azurerm_postgresql_server" "sonarqube" {
  name                = var.database_server.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name = var.database_server.sku
  storage_mb                   = var.database_server.storage_mb
  backup_retention_days        = var.database_server.backup_retention_days
  geo_redundant_backup_enabled = var.database_server.geo_redundant_backup_enabled
  auto_grow_enabled            = var.database_server.auto_grow_enabled
  administrator_login          = var.database_server.administrator_login
  administrator_login_password = random_password.postgresql_server_database.result
  version                      = var.database_server.version
  ssl_enforcement_enabled      = var.database_server.ssl_enforcement_enabled
  ssl_minimal_tls_version_enforced = var.database_server.ssl_minimal_tls_version_enforced
  tags = local.tags
}

resource "azurerm_postgresql_database" "sonarqube" {
  name                = var.database_server.database.name
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_postgresql_server.sonarqube.name
  charset             = var.database_server.database.charset
  collation           = var.database_server.database.collation
}

resource "azurerm_postgresql_firewall_rule" "this" {
  for_each = var.whitelist_ips
  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_postgresql_server.sonarqube.name
  start_ip_address    = each.value.start_ip_address
  end_ip_address      = each.value.end_ip_address
}

resource "azurerm_dns_a_record" "sonarqube" {
  count = var.dns == null ? 0 : 1
  name                = var.dns.dns_record_name
  zone_name           = data.azurerm_dns_zone.this.0.name
  resource_group_name = var.dns.dns_zone_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.sonarqube.id
  tags = local.tags
}