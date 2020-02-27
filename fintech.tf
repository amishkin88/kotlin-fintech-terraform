resource "azurerm_resource_group" "rg" {
    name     = "FintechKotlin"
    location = "North Europe"
}

provider "azurerm" {
    version = "~>1.32.0"
    subscription_id = var.subscription_id
    tenant_id = var.tenant_id
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "tinkoff-kotlin-vnet"
    address_space       = ["10.4.0.0/16"]
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "kafka" {
    name = "kafka"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefix = "10.4.1.0/24"
}

resource "azurerm_subnet" "aks" {
    name = "aks"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefix = "10.4.2.0/24"
}

resource "azurerm_subnet" "psql" {
    name = "psql"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefix = "10.4.3.0/24"
}

resource "azurerm_storage_account" "stac"{
    name                     = "tinkoffkotlinkafka"
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "stcontainer" {
    name                  = "tinkoffkotlinkafka"
    resource_group_name   = azurerm_resource_group.rg.name
    storage_account_name  = azurerm_storage_account.stac.name
    container_access_type = "private"
}

resource "azurerm_hdinsight_kafka_cluster" "kafka" {
    name                = "tinkoffkotlinkafka"
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    cluster_version     = "4.0.1000.1"
    tier                = "Standard"

    component_version {
        kafka = "2.1"
    }

    gateway {
        enabled  = true
        username = var.admin_login
        password = var.admin_password
    }

    storage_account {
        storage_container_id = azurerm_storage_container.stcontainer.id
        storage_account_key  = azurerm_storage_account.stac.primary_access_key
        is_default           = true
    }

    roles {
        head_node {
            vm_size  = "STANDARD_A2M_V2"
            username = var.admin_login
            password = var.admin_password
            subnet_id = azurerm_subnet.kafka.id
            virtual_network_id = azurerm_virtual_network.vnet.id
        }

        worker_node {
            vm_size                  = "STANDARD_A2M_V2"
            username = var.admin_login
            password = var.admin_password
            number_of_disks_per_node = 1
            target_instance_count    = 3
            subnet_id = azurerm_subnet.kafka.id
            virtual_network_id = azurerm_virtual_network.vnet.id

        }

        zookeeper_node {
            vm_size  = "Standard_A2_v2"
            username = var.admin_login
            password = var.admin_password
            subnet_id = azurerm_subnet.kafka.id
            virtual_network_id = azurerm_virtual_network.vnet.id
        }
    }
}

resource "azurerm_postgresql_server" "db" {
    name                = "tinkoff-kotlin-psql-1"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    sku {
        name     = "B_Gen5_2"
        capacity = 2
        tier     = "Basic"
        family   = "Gen5"
    }

    storage_profile {
        storage_mb            = 5120
        backup_retention_days = 7
        geo_redundant_backup  = "Disabled"
#        auto_grow             = "Enabled"
    }

    administrator_login          = var.admin_login
    administrator_login_password = var.admin_password
    version                      = "11"
    ssl_enforcement              = "Enabled"
}

resource "azurerm_kubernetes_cluster" "k8s" {
    name                = "kotlin-aks1"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    dns_prefix          = "tinkoff"

    agent_pool_profile {
        name       = "default"
        count = 1
        vm_size    = "Standard_D2_v2"
        vnet_subnet_id = azurerm_subnet.aks.id
    }

    service_principal {
        client_id     = var.sp_client_id
        client_secret = var.sp_client_secret
    }

    tags = {
        Environment = "Fintech"
    }
}

output "client_certificate" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate
}

output "kube_config" {
    value = azurerm_kubernetes_cluster.k8s.kube_config_raw
}