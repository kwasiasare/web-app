terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate${random_id.storage_suffix.hex}"
    container_name       = "tfstate"
    key                  = "web-app.tfstate"
  }
}

resource "random_id" "storage_suffix" {
  byte_length = 4
}