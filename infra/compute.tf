resource "azurerm_static_web_app" "main" {
  name                = "swa-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_tier            = "Standard"
  sku_size            = "Standard"

  tags = local.common_tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project_name}-${var.environment}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = false

  tags = local.common_tags
}

resource "azurerm_container_app" "main" {
  name                         = "ca-${var.project_name}-${var.environment}"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    min_replicas = 0
    max_replicas = 10

    container {
      name   = "api"
      image  = var.container_app_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "SQL_CONNECTION_STRING"
        secret_name = "sql-connection-string"
      }

      env {
        name        = "APPINSIGHTS_INSTRUMENTATIONKEY"
        secret_name = "appinsights-key"
      }
    }
  }

  secret {
    name  = "sql-connection-string"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=sql-connection-string)"
  }

  secret {
    name  = "appinsights-key"
    value = azurerm_application_insights.main.instrumentation_key
  }

  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 80

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.container_app_kv_secrets_user]
}