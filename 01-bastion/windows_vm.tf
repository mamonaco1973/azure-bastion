# Define a network interface for the Windows VM
resource "azurerm_network_interface" "windows-vm-nic" {
  name                = "windows-vm-nic"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create the Windows Server 2022 VM
resource "azurerm_windows_virtual_machine" "windows-vm" {
  name                = "windows-vm"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  size                = "Standard_B2ms"  # Suitable for Windows workloads
  admin_username      = "sysadmin"
  admin_password      = random_password.vm_password.result
  
  network_interface_ids = [
    azurerm_network_interface.windows-vm-nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  provision_vm_agent        = true
  enable_automatic_updates  = true
}
