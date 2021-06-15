provider "azurerm" {
   version = "~>1.40"

   subscription_id = var.subscription_id
   tenant_id = var.tenant_id
   client_id = var.client_id
   client_secret = var.client_secret
}
variable subscription_id {}
variable tenant_id {}
variable client_id {}
variable client_secret {}

resource "azurerm_resource_group" "demo" {
  name     = "rg-test"
  location = "West Europe"
}

resource "azurerm_network_security_group" "demo" {
  name                = "testSecurityGroup1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  custom_rules = [
    {
      name                   = "my443"
      priority               = 201
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "tcp"
      source_port_range      = "*"
      destination_port_range = "443"
      description            = "description-my443"
    },
    {
      name                    = "myhttp"
      priority                = 200
      direction               = "Inbound"
      access                  = "Allow"
      protocol                = "tcp"
      source_port_range       = "*"
      destination_port_range  = "8080"
      description             = "description-http"
    },
  ]
}

resource "azurerm_network_ddos_protection_plan" "demo" {
  name                = "ddospplan1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
}

resource "azurerm_virtual_network" "demo" {
  name                = "vnet1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.demo.id
    enable = true
  }

  subnet {
    name           = "subnet1"
    address_prefix = "10.0.1.0/24"
  }

  subnet {
    name           = "subnet2"
    address_prefix = "10.0.2.0/24"
  }

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_network_interface" "demo" {
count = 2
  name                = "vm-nic-${count.index}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet${count.index}.demo.id
    private_ip_address_allocation = "Dynamic"
  }
}

data "azurerm_key_vault_secret" "mySecret" {
name = "labvmkey"
vault_uri = "https://yourKeyVault.vault.azure.net/"
}

resource "azurerm_virtual_machine" "demo" {
   count = 2
  name                  = "my-vm-${count.index}"
  location              = azurerm_resource_group.demo.location
  resource_group_name   = azurerm_resource_group.demo.name
  network_interface_ids = [azurerm_network_interface.demo.*.id[count.index]]
  vm_size               = "Standard_F2"
 
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "${data.azurerm_key_vault_secret.mySecret.value}"
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_storage_account" "demo" {
  name                     = "storageaccountname"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}