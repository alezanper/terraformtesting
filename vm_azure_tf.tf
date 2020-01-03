#terraform {
#  required_version = ">= 0.11"
#  backend "azurerm" {
#    storage_account_name = "diage875857206b10c9d"
#    container_name        = "containestatus"
#    key                   = "terraform.tfstate"
#  }
#}

# Configure the Microsoft Azure Provider
provider "azurerm" {
    
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "RG-APP"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"
	domain_name_label            = "webapptest"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "webappdev"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "webappdev"
        admin_username = "jaime.garcia"
        admin_password = "Globan1#"
    }

    os_profile_linux_config {
        disable_password_authentication = false
        #ssh_keys {
        #   path     = "/home/jaime/.ssh/authorized_keys"
        #    key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDfnHEAv7HVCylYrPwomn5Ba9TYgchulN/1Dgzo5pIsNV1pSMdZGd3jr4NsOWkSC1Zj+NViZ9+uhPkHBC9iAMMQM+G4qWKCmI8IPjBLYk/Jg5rPW8PolBipMwkJ72WQv9rTa7yjo/FtKOJqsq21rO2LQuMUXqz39SoBK7jSElGKwX1rW3TDhG5hlqRTmIbLIaqnZRlDpNqrWiH0lfucRik2rh+k1x5yoHm0oOmnTAthWzXEz4axNNm1gCdTSyM2iVvaiq2HOnbiFTBy9L4pM2y0gYMiENr6Y4oW1iIFA3uwE6M+eTyq/xXO8eIXcwwSeqfUcyL5yy2SLww2wPFD9MHD jaime@cc-7b8d79a8-76cdcb745f-v2bkv"
        #}
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_virtual_machine_extension" "myterraformext" {
  name                 = "hostname"
  location             = "eastus"
  resource_group_name  = "RG-APP"
  virtual_machine_name = "${azurerm_virtual_machine.myterraformvm.name}"
  publisher            = "Microsoft.OSTCExtensions"
  type                 = "CustomScriptForLinux"
  type_handler_version = "1.2"
  settings = <<SETTINGS
   {
       "fileUris": ["https://scrip1.blob.core.windows.net/script/script.sh"],
       "commandToExecute": "sh script.sh"
  }
SETTINGS
  
}