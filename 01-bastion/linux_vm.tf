# Define a network interface to connect the VM to the network
resource "azurerm_network_interface" "linux-vm-nic" {
  name                = "linux-vm-nic"                           # Name of the NIC
  location            = var.project_location                     # NIC location matches the resource group
  resource_group_name = azurerm_resource_group.project_rg.name   # Links to the resource group

  # IP configuration for the NIC
  ip_configuration {
    name                          = "internal"                    # IP config name
    subnet_id                     = azurerm_subnet.vm-subnet.id   # Subnet ID
    private_ip_address_allocation = "Dynamic"                     # Dynamically assign private IP
  }
}

resource "azurerm_linux_virtual_machine" "linux-vm" {
  name                = "linux-vm"                              # Name of the VM
  location            = var.project_location                    # VM location matches the resource group
  resource_group_name = azurerm_resource_group.project_rg.name  # Links to the resource group
  size                = "Standard_B1s"                          # VM size
  admin_username      = "sysadmin"                              # Admin username for the VM
  admin_password      = random_password.vm_password.result
  disable_password_authentication = false
  
  network_interface_ids = [
     azurerm_network_interface.linux-vm-nic.id                # Associate NIC with the VM
  ]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"                        # Enable read/write caching
    storage_account_type = "Standard_LRS"                     # Standard locally redundant storage
  }

  # Use an Ubuntu image from the marketplace
  source_image_reference {
    publisher = "canonical"                          # Image publisher
    offer     = "ubuntu-24_04-lts"                   # Image offer
    sku       = "server"                             # Image SKU
    version   = "latest"                             # Latest version
  }
}