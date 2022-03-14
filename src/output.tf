output "sonarqube" {
  value = {
    url = "${local.sonarqube_url_protocol}://${local.sonarqube_address}"
    username = "admin"
    password = "admin"
  }
}

output "sonarqube_virtual_machine" {
  value = {
    public_ip = azurerm_public_ip.sonarqube.ip_address
    private_ip = azurerm_network_interface.sonarqube.private_ip_address
    username = var.vm_sonarqube.user
    ssh = "ssh -i ${var.vm_sonarqube.ssh.private_key_path} ${var.vm_sonarqube.user}@${azurerm_public_ip.sonarqube.ip_address}"
  }
}

output "sonarqube_database" {
  sensitive = true
  value = {
    hostname = azurerm_postgresql_server.sonarqube.fqdn
    username = local.database_username
    password = azurerm_postgresql_server.sonarqube.administrator_login_password
    jdbc = local.database_jdbc
  }
}