variable "subscription_id" {
    description = "subscription_id"
}

variable "tenant_id" {
    description = "tenant_id"
}

provider "azurerm" {
    version = "~>1.32.0"
    subscription_id = "${var.subscription_id}"
    tenant_id = "${var.tenant_id}"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "FintechKotlin-vnet"
    address_space       = ["10.0.4.0/24"]
    location            = "West Europe"
    resource_group_name = "FintechKotlin"
}