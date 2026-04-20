variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-web-app-dev"
}

variable "location" {
  description = "The Azure region for resources"
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "web-app"
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "sql_admin_username" {
  description = "SQL Server admin username"
  type        = string
  default     = "sqladmin"
  sensitive   = true
}

variable "container_app_image" {
  description = "Container image for the Container App"
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

locals {
  common_tags = {
    environment  = var.environment
    project      = var.project_name
    managed-by   = "terraform"
  }
}