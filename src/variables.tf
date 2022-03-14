locals {
  tags = merge(
    var.tags,
    {
      subscription   = data.azurerm_subscription.current.display_name
      resource_group = var.resource_group.name
    }
  )
  network_security_rules = {
    for r in flatten([
      for subnetName, subnetValues in var.vnet.subnets : [
        for rule in subnetValues.network_security_rules : merge(
          rule,
          { "subnet" : subnetName, "key" : "${subnetName}-${rule.name}" }
        )
      ]
    ]) : r.key => r
  }
  database_jdbc = "jdbc:postgresql://${azurerm_postgresql_server.sonarqube.fqdn}/${azurerm_postgresql_database.sonarqube.name}"
  database_username = "${var.database_server.administrator_login}@${var.database_server.name}"
  sonarqube_address = var.dns == null ? azurerm_public_ip.sonarqube.ip_address : azurerm_dns_a_record.sonarqube.0.fqdn
  sonarqube_url_protocol = var.ssl_certificates == null ? "http" : "https"
  nginx_conf_file = var.ssl_certificates == null ? "${path.module}/templates/nginx-conf.tftpl" : "${path.module}/templates/nginx-ssl-conf.tftpl"
  nginx_ssl_public_key = var.ssl_certificates == null ? "" : file(var.ssl_certificates.certificate_public_key_path)
  nginx_ssl_private_key = var.ssl_certificates == null ? "" : file(var.ssl_certificates.certificate_private_key_path)
}

data "azurerm_subscription" "current" {}

data "azurerm_dns_zone" "this" {
  count = var.dns == null ? 0 : 1
  name                = var.dns.dns_zone_name
  resource_group_name = var.dns.dns_zone_resource_group_name
}

variable "resource_group" {
  type = object({
    name = string, location = string
  })
  default = {
    name     = "sonarqube"
    location = "eastus"
  }
}

variable "vnet" {
  type = object({
    name = string, address_space = list(string), 
    subnets = map(object({
      address_space = list(string),
      network_security_rules = list(object({
        name                  = string, priority = number, direction = string, access = string,
        protocol              = string, source_port_range = string, destination_port_range = string,
        source_address_prefix = string, destination_address_prefix = string
      }))
    }))
  })
  default = {
    name = "sonarqube"
    address_space = ["10.0.0.0/16"]
    subnets = {
      default = {
        address_space = ["10.0.0.0/24"]
        network_security_rules : [
          {
            name = "allow-https"
            priority = 1000
            direction = "Inbound"
            access = "Allow"
            protocol = "TCP"
            source_port_range = "*"
            destination_port_range = "443"
            source_address_prefix = "*"
            destination_address_prefix = "*"
          },
          {
            name = "allow-http"
            priority = 1010
            direction = "Inbound"
            access = "Allow"
            protocol = "TCP"
            source_port_range = "*"
            destination_port_range = "80"
            source_address_prefix = "*"
            destination_address_prefix = "*"
          },
          {
            name = "allow-ssh"
            priority = 100
            direction = "Inbound"
            access = "Allow"
            protocol = "TCP"
            source_port_range = "*"
            destination_port_range = "22"
            source_address_prefix = "*"
            destination_address_prefix = "*"
          }
        ]
      }
    }
  }
}

variable "vm_sonarqube" {
  type = object({
    subnet = string, name = string, user = string,
    ssh = object({
      private_key_path = string, public_key_path = string
    }),
    os_disk = object({
      caching = string, storage_account_type = string, disk_size_gb = number
    }),
    external_disk = object({
      lun = string, caching = string, storage_account_type = string, disk_size_gb = number
    }),
    source_image_reference = object({
      publisher = string, offer = string, sku = string, version = string
    }),
    size = string
  })
  default = {
    subnet = "default"
    name = "sonarqube"
    user = "adminuser"
    ssh = {
      private_key_path = "./keys/key"
      public_key_path = "./keys/key.pub"
    }
    os_disk = {
      caching = "None"
      storage_account_type = "Standard_LRS"
      disk_size_gb = 50
    }
    external_disk = {
      lun = 0
      caching = "ReadOnly"
      storage_account_type = "Standard_LRS"
      disk_size_gb = 20
    }
    source_image_reference = {
      publisher = "canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts"
      version   = "latest"
    }
    size = "Standard_D2as_v5"
  }
}

variable database_server {
  type = object({
    name = string, sku = string, storage_mb = number, backup_retention_days = number, 
    geo_redundant_backup_enabled = bool, auto_grow_enabled = bool,
    administrator_login = string, version = string, 
    ssl_enforcement_enabled = bool, ssl_minimal_tls_version_enforced = string,
    database = object({
      name = string, charset = string, collation = string
    })
  })
  default = {
    name = "poc-sonarqube"
    sku = "B_Gen5_2"
    storage_mb = 51200
    backup_retention_days = 7
    geo_redundant_backup_enabled = false
    auto_grow_enabled = true
    administrator_login = "psqladmin"
    version = "11"
    ssl_enforcement_enabled      = true
    ssl_minimal_tls_version_enforced = "TLS1_2"
    database = {
      name = "sonar"
      charset = "UTF8"
      collation = "en-US"
    }
  }
}

variable whitelist_ips {
  default = {
    azure = {
      start_ip_address = "0.0.0.0"
      end_ip_address = "0.0.0.0"
    }
    office = {
      start_ip_address = "0.0.0.0"
      end_ip_address = "255.255.255.255"
    }
  }
}

variable sonarqube_docker_image {
  type = string
  default = "sonarqube:9.3.0-community"
}

variable nginx_docker_image {
  type = string
  default = "nginx:1.21"
}

variable dns {
  type = object({
    dns_zone_name = string
    dns_zone_resource_group_name = string
    dns_record_name = string
  })
  default = null
}

variable ssl_certificates {
  type = object({
    certificate_private_key_path = string
    certificate_public_key_path = string
  })
  default = null
}

variable tags {
  type = map(string)
  default = {
    "environment" = "poc"
  }
}