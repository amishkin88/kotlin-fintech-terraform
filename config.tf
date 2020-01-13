provider "azurerm" {
    version = "~>1.32.0"
    client_id = "${var.service_principal_id}"
    client_secret = "${var.service_principal_key}"
    subscription_id = "${var.subscription_id}"
    tenant_id = "${var.tenant_id}"
}