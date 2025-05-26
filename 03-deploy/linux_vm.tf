############################################
# NETWORK INTERFACE: VIRTUAL MACHINE NIC
############################################
resource "azurerm_network_interface" "games_nic" {
  name                = "games-nic"                                    # Logical name assigned to the NIC
  location            = data.azurerm_resource_group.packer_rg.location # Ensure NIC is deployed in the same region as the resource group
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Assign NIC to the same resource group

  ip_configuration {
    name                          = "internal"                           # Name of the NIC's IP configuration
    subnet_id                     = data.azurerm_subnet.packer_subnet.id # Attach NIC to a specific subnet (defined elsewhere)
    private_ip_address_allocation = "Dynamic"                            # Let Azure dynamically assign a private IP
    public_ip_address_id          = azurerm_public_ip.games_pip.id       # Bind a static public IP for external access
  }
}

############################################
# PUBLIC IP: ASSIGN TO THE VIRTUAL MACHINE
############################################
resource "azurerm_public_ip" "games_pip" {
  name                = "games-pip"                                    # Name for the public IP resource
  location            = data.azurerm_resource_group.packer_rg.location # Same location as other resources
  resource_group_name = data.azurerm_resource_group.packer_rg.name     # Same resource group for logical grouping
  allocation_method   = "Static"                                       # Use a static public IP (fixed over time)
  sku                 = "Standard"                                     # Use Standard SKU (recommended for production scenarios)

  domain_name_label = "games-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}"
  # Generate a globally unique DNS name based on subscription ID prefix
}

############################################
# RANDOM PASSWORD: SECURE LINUX LOGIN
############################################
resource "random_password" "ubuntu" {
  length  = 24    # Length of generated password (strong entropy)
  special = true  # Avoid special characters (useful for services that can't handle them)
}

############################################
# VIRTUAL MACHINE: LINUX DEPLOYMENT
############################################
resource "azurerm_linux_virtual_machine" "games_vm" {
  name                            = "games-vm"                                     # Name of the VM in the Azure portal
  location                        = data.azurerm_resource_group.packer_rg.location # Must match resource group location
  resource_group_name             = data.azurerm_resource_group.packer_rg.name     # VM belongs to this RG
  size                            = "Standard_B1s"                                 # Use a small VM size (suitable for lightweight tasks)
  admin_username                  = "ubuntu"                                       # Login username
  admin_password                  = random_password.ubuntu.result                  # Pull password from secure random generator
  disable_password_authentication = false                                          # Allow password-based login (set to true to use SSH-only auth)

  network_interface_ids = [
    azurerm_network_interface.games_nic.id # Attach previously defined NIC to the VM
  ]

  os_disk {
    caching              = "ReadWrite"    # Enable both read and write caching for improved performance
    storage_account_type = "Standard_LRS" # Use locally-redundant storage (cheaper, less resilient than ZRS)
  }

  source_image_id = data.azurerm_image.games_image.id # Use a custom image reference (from Packer or shared gallery)

  custom_data = base64encode(templatefile("${path.module}/scripts/custom_data.sh", {
    image = data.azurerm_image.games_image.name
  }))

}

output "games_vm_fqdn" {
  description = "FQDN of the public IP assigned to the games VM"
  value       = azurerm_public_ip.games_pip.fqdn
}

