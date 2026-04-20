resource "random_password" "sql_admin" {
  length  = 20
  special = true
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.project_name}-${var.environment}-${random_id.sql_suffix.hex}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = azurerm_container_app.main.identity[0].principal_id
    object_id                   = azurerm_container_app.main.identity[0].principal_id
    azuread_authentication_only = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "random_id" "sql_suffix" {
  byte_length = 4
}

resource "azurerm_mssql_database" "main" {
  name           = "sqldb-${var.project_name}-${var.environment}"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "GP_S_Gen5_1"
  zone_redundant = false
  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5

  threat_detection_policy {
    state                      = "Enabled"
    email_account_admins       = "Enabled"
    retention_days             = 30
  }

  transparent_data_encryption_enabled = true

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_virtual_network_rule" "main" {
  name      = "vnet-rule"
  server_id = azurerm_mssql_server.main.id
  subnet_id = azurerm_subnet.database.id
}