# Setup azurerm as a state backend
terraform {
  backend "azurerm" {
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "bdcc" {
  name = "rg-${var.ENV}-${var.LOCATION}"
  location = var.LOCATION

  tags = {
    region = var.BDCC_REGION
    env = var.ENV
  }
}

resource "azurerm_storage_account" "bdcc" {
  depends_on = [
    azurerm_resource_group.bdcc]

  name = "st${var.ENV}${var.LOCATION}"
  resource_group_name = azurerm_resource_group.bdcc.name
  location = azurerm_resource_group.bdcc.location
  account_tier = "Standard"
  account_replication_type = var.STORAGE_ACCOUNT_REPLICATION_TYPE
  is_hns_enabled = "true"

  tags = {
    region = var.BDCC_REGION
    env = var.ENV
  }
}

resource "azurerm_role_assignment" "role_assignment" {
  depends_on = [
    azurerm_storage_account.bdcc]

  scope                = azurerm_storage_account.bdcc.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gen2_data" {
  depends_on = [
    azurerm_storage_account.bdcc]

  name = "data"
  storage_account_id = azurerm_storage_account.bdcc.id
}

resource "azurerm_container_registry" "bdcc" {
  depends_on = [
    azurerm_resource_group.bdcc]

  name                = "acr${var.ENV}${var.LOCATION}"
  resource_group_name = azurerm_resource_group.bdcc.name
  location            = azurerm_resource_group.bdcc.location
  sku                 = "Basic"
}

resource "azurerm_kubernetes_cluster" "bdcc" {
  depends_on = [
    azurerm_resource_group.bdcc]

  name                = "aks-${var.ENV}-${var.LOCATION}"
  location            = azurerm_resource_group.bdcc.location
  resource_group_name = azurerm_resource_group.bdcc.name
  dns_prefix          = "bdcc${var.ENV}"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    region = var.BDCC_REGION
    env = var.ENV
  }
}

resource "azurerm_role_assignment" "acr_role_assignment" {
  depends_on = [
    azurerm_kubernetes_cluster.bdcc]

  principal_id                     = azurerm_kubernetes_cluster.bdcc.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.bdcc.id
  skip_service_principal_aad_check = true
}

output "acr_name" {
  value = azurerm_container_registry.bdcc.name
}

output "acr_url" {
  value = azurerm_container_registry.bdcc.login_server
}

output "k8s_api" {
  value = azurerm_kubernetes_cluster.bdcc.fqdn
}

output "kube_config" {
  sensitive = true
  value = azurerm_kubernetes_cluster.bdcc.kube_config_raw
}

output "storage_account_name" {
  value = azurerm_storage_account.bdcc.name
}

output "storage_account_access_key" {
  sensitive = true
  value = azurerm_storage_account.bdcc.primary_access_key
}

output "storage_account_container_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.gen2_data.name
}
