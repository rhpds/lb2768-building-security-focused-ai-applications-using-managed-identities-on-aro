variable "tags" {
  type = map(string)
  default = {
    environment = "development"
    owner       = "your@email.address"
  }
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID (needed with the new Auth method)"
  default     = "52cc7297-fdde-4df5-bc6d-f6cca2d46aa2"
}

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.53"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.3.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}


resource "random_string" "openai_suffix" {
  length           = 8
  special          = false
  upper            = false
  numeric          = false
}

resource "azurerm_resource_group" "openai" {
  name     = "rhoai-openai"
  location = var.location
}

resource "azurerm_cognitive_account" "openai" {
  name                = "rhoai-${random_string.openai_suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.openai.name
  kind                = "OpenAI"
  sku_name = "S0"
  tags = var.tags
}

resource "azurerm_cognitive_deployment" "gpt35" {
  name                 = "rhoai-gpt35${random_string.openai_suffix.result}"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  version_upgrade_option = "OnceNewDefaultVersionAvailable"
  rai_policy_name = "Microsoft.Default"
#   current_capacity = 10
  sku {
    name = "Standard"
    capacity = 10
  }
  model {
    format = "OpenAI"
    name = "gpt-35-turbo"
    version = "0301"
  }
}

resource "azurerm_cognitive_account" "gpt4" {
  name                = "rhoai-gpt4-${random_string.openai_suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.openai.name
  kind                = "OpenAI"
  sku_name = "S0"
  tags = var.tags
}

resource "azurerm_cognitive_deployment" "gpt4" {
  name                 = "rhoai-gpt4-${random_string.openai_suffix.result}"
  cognitive_account_id = azurerm_cognitive_account.gpt4.id
  version_upgrade_option = "OnceNewDefaultVersionAvailable"
  rai_policy_name = "Microsoft.Default"
#   current_capacity = 10
  sku {
    name = "Standard"
    capacity = 10
  }
  model {
    format = "OpenAI"
    name = "gpt-4"
    version = "0613"
  }
}

resource "azurerm_cognitive_deployment" "textembedding" {
  name                 = "rhoai-${random_string.openai_suffix.result}-te"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  version_upgrade_option = "OnceNewDefaultVersionAvailable"
  rai_policy_name = "Microsoft.Default"
#   current_capacity = 10
  sku {
    name = "Standard"
    capacity = 10
  }
  model {
    format = "OpenAI"
    name = "text-embedding-3-small"
    # version = "0301"
  }
}

resource "azurerm_search_service" "openai" {
  name                = "rhoai-${random_string.openai_suffix.result}"
  resource_group_name = azurerm_resource_group.openai.name
  location            = var.location
  sku                 = "basic"
  replica_count       = 1
  partition_count     = 1
  tags = var.tags
}

resource "azurerm_postgresql_server" "openai" {
  name                = "rhoai-${random_string.openai_suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.openai.name

  administrator_login          = "psqladmin"
  administrator_login_password = "Redhat041"

  sku_name   = "B_Gen5_1"
  version    = "11"
  storage_mb = 32 * 1024
  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
  tags = var.tags
}

resource "azurerm_postgresql_firewall_rule" "openai" {
  name                = azurerm_postgresql_server.openai.name
  resource_group_name = azurerm_resource_group.openai.name
  server_name         = azurerm_postgresql_server.openai.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


resource "azurerm_storage_account" "openai" {
  name                = "rhoai${random_string.openai_suffix.result}"
  resource_group_name = azurerm_resource_group.openai.name
  location            = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = var.tags
}

resource "azurerm_storage_container" "parasol" {
  name                  = "parasol"
  storage_account_name  = azurerm_storage_account.openai.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "cal-drivers" {
  name                   = "cal-drivers.pdf"
  storage_account_name   = azurerm_storage_account.openai.name
  storage_container_name = azurerm_storage_container.parasol.name
  type                   = "Block"
  source                 = "cal-driver.pdf"
}

output "dotenv" {
  sensitive = true
  value = <<EOF
    PGSQL_URI=${azurerm_postgresql_server.openai.fqdn}
    AZURE_OPENAI_ENDPOINT=https://canadaeast.api.cognitive.microsoft.com/
    # AZURE_OPENAI_ENDPOINT=https://${var.location}.api.cognitive.microsoft.com/
    AZURE_OPENAI_API_KEY=${azurerm_cognitive_account.openai.primary_access_key}
    OPENAI_API_VERSION=2024-05-01-preview
    AZURE_DEPLOYMENT=${azurerm_cognitive_deployment.openai.name}
    AZURE_AI_SEARCH_SERVICE_NAME=${azurerm_search_service.openai.name}
    AZURE_AI_SEARCH_API_KEY=${azurerm_search_service.openai.primary_key}
    AZURE_AI_SEARCH_INDEX_NAME=parasol
    AZURE_EMBEDDING=${azurerm_cognitive_deployment.textembedding.name}
EOF
}
