############################################
# NETWORK INTERFACE: VIRTUAL MACHINE NIC
############################################
resource "azurerm_network_interface" "desktop_nic" {
  name                = "desktop-nic"                                  # Logical name assigned to the NIC
  location            = data.azurerm_resource_group.packer_rg.location # Ensure NIC is deployed in the same region as the resource group
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Assign NIC to the same resource group

  ip_configuration {
    name                          = "internal"                           # Name of the NIC's IP configuration
    subnet_id                     = data.azurerm_subnet.packer_subnet.id # Attach NIC to a specific subnet (defined elsewhere)
    private_ip_address_allocation = "Dynamic"                            # Let Azure dynamically assign a private IP
    public_ip_address_id          = azurerm_public_ip.desktop_pip.id     # Bind a static public IP for external access
  }
}

############################################
# PUBLIC IP: ASSIGN TO THE VIRTUAL MACHINE
############################################
resource "azurerm_public_ip" "desktop_pip" {
  name                = "desktop-pip"                                  # Name for the public IP resource
  location            = data.azurerm_resource_group.packer_rg.location # Same location as other resources
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Same resource group for logical grouping
  allocation_method   = "Static"                                       # Use a static public IP (fixed over time)
  sku                 = "Standard"                                     # Use Standard SKU (recommended for production scenarios)

  domain_name_label = "desktop-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}"
  # Generate a globally unique DNS name based on subscription ID prefix
}

############################################
# RANDOM PASSWORD: SECURE WINDOWS LOGIN
############################################
resource "random_password" "windows" {
  length  = 24    # Length of generated password (strong entropy)
  special = false # Avoid special characters (useful for services that can't handle them)
}

############################################
# VIRTUAL MACHINE: WINDOWS DEPLOYMENT
############################################
resource "azurerm_windows_virtual_machine" "desktop_vm" {
  name                  = "desktop-vm"                                   # Name of the VM in the Azure portal
  location              = data.azurerm_resource_group.packer_rg.location # Must match resource group location
  resource_group_name   = data.azurerm_resource_group.packer_rg.name     # VM belongs to this RG
  size                  = "Standard_B2s"                                 # Small VM size for basic tasks
  admin_username        = "azureadmin"                                   # Windows admin login user 
  admin_password        = random_password.windows.result                 # Secure random password
  provision_vm_agent    = true                                           # Required for extensions and custom script execution

  network_interface_ids = [
    azurerm_network_interface.desktop_nic.id                             # Attach previously defined NIC to the VM
  ]

  os_disk {
    caching              = "ReadWrite"                                   # Read/write cache for improved performance
    storage_account_type = "Standard_LRS"                                # Locally redundant storage
  }

  source_image_id = data.azurerm_image.desktop_image.id                  # Use Packer-built custom Windows image

  ############################################
  # BOOTSTRAP SCRIPT (OPTIONAL)
  ############################################
  custom_data = base64encode(templatefile("${path.module}/scripts/custom_data.ps1", {
    image = data.azurerm_image.desktop_image.name
  }))                                                                     # PowerShell-based init script (must be base64-encoded)
}

############################################
# VM EXTENSION: EXECUTE CUSTOM_DATA SCRIPT
############################################
resource "azurerm_virtual_machine_extension" "desktop_run_custom_data" {
  name                       = "run-custom-data"                               # Logical name for this VM extension instance
  virtual_machine_id         = azurerm_windows_virtual_machine.desktop_vm.id   # Target the Windows VM we just provisioned
  publisher                  = "Microsoft.Compute"                             # Microsoft-published extension provider for script execution
  type                       = "CustomScriptExtension"                         # Use the extension type designed for running startup scripts
  type_handler_version       = "1.10"                                          # Stable handler version that supports PowerShell and file operations
  auto_upgrade_minor_version = true                                            # Allow minor version upgrades for compatibility and security

   settings = jsonencode({
    commandToExecute = join(" ", [
      "powershell",
      "-ExecutionPolicy Bypass",
      "-Command \"",
      "if (Test-Path 'C:\\AzureData\\CustomData.bin') {",
        "Copy-Item 'C:\\AzureData\\CustomData.bin' 'C:\\AzureData\\custom_data.ps1' -Force;",
        "powershell -ExecutionPolicy Bypass -File 'C:\\AzureData\\custom_data.ps1'",
      "} else {",
        "Write-Host 'CustomData.bin not found.'",
      "}\""
    ])
  })
}

output "desktop_vm_fqdn" {
  description = "FQDN of the public IP assigned to the games VM"
  value       = azurerm_public_ip.desktop_pip.fqdn
}
