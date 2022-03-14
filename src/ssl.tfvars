dns = {
  dns_zone_name = "cloudfeeling.com.br"
  dns_zone_resource_group_name = "cloudfeeling-dns-rg"
  dns_record_name = "sonarqube"
}

ssl_certificates = {
  certificate_public_key_path = "../../../keys/public.crt"
  certificate_private_key_path = "../../../keys/private.key"
}