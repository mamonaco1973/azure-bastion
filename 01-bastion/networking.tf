#############################################
# VIRTUAL NETWORK CONFIGURATION
#############################################

# Create a virtual network to contain subnets for apps and bastion
resource "azurerm_virtual_network" "project-vnet" {
  name                = var.project_vnet                              # Name of the virtual network (VNet)
  address_space       = ["10.0.0.0/23"]                               # IP address range for the entire VNet
  location            = var.project_location                          # Region where the VNet will be deployed
  resource_group_name = azurerm_resource_group.project_rg.name        # Resource group to place the VNet into
}

# Define the subnet for application workloads (e.g., VM, container)
resource "azurerm_subnet" "vm-subnet" {
  name                 = var.project_subnet                           # Subnet name (for app workloads)
  resource_group_name  = azurerm_resource_group.project_rg.name       # Must match the VNet’s RG
  virtual_network_name = azurerm_virtual_network.project-vnet.name    # Parent virtual network
  address_prefixes     = ["10.0.0.0/25"]                              # IP range (first half of VNet CIDR block)
}

# Define the dedicated subnet for Azure Bastion (must use reserved name)
resource "azurerm_subnet" "bastion-subnet" {
  name                 = "AzureBastionSubnet"                         # Azure requires this exact name for Bastion
  resource_group_name  = azurerm_resource_group.project_rg.name       # Resource group
  virtual_network_name = azurerm_virtual_network.project-vnet.name    # Parent VNet
  address_prefixes     = ["10.0.1.0/25"]                              # IP range (second half of VNet CIDR block)
}

#############################################
# NETWORK SECURITY GROUP FOR APP SUBNET
#############################################

# Create NSG to control inbound traffic to the application subnet
resource "azurerm_network_security_group" "vm-nsg" {
  name                = "vm-nsg"                                       # Name of NSG
  location            = var.project_location                           # Region
  resource_group_name = azurerm_resource_group.project_rg.name         # Resource group

  # Inbound SSH rule - allow port 22 from anywhere (customize as needed)
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Inbound RDP rule - allow port 3389 (for Windows VMs if needed)
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Inbound HTTP rule - allow port 80 for web traffic
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#############################################
# NETWORK SECURITY GROUP FOR BASTION SUBNET
#############################################

# NSG tailored for Bastion subnet - enables required traffic
resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "bastion-nsg"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  # Required by Azure Bastion for communication with Azure infrastructure
  security_rule {
    name                       = "GatewayManager"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"                      # Azure internal service tag
    destination_address_prefix = "*"
  }

  # Required inbound access from Internet to Bastion’s public IP (HTTPS)
  security_rule {
    name                       = "Internet-Bastion-PublicIP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound access from Bastion to VMs (port 22 and 3389 only)
  security_rule {
    name                       = "OutboundVirtualNetwork"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]                         # Required for SSH/RDP
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"                      # Internal traffic only
  }

  # Outbound access to Azure infrastructure (HTTPS)
  security_rule {
    name                       = "OutboundToAzureCloud"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"                          # Azure internal control plane
  }
}

#############################################
# ASSOCIATE NSGs TO THEIR SUBNETS
#############################################

# Bind application subnet to its NSG
resource "azurerm_subnet_network_security_group_association" "vm-nsg-assoc" {
  subnet_id                 = azurerm_subnet.vm-subnet.id
  network_security_group_id = azurerm_network_security_group.vm-nsg.id
}

# Bind Bastion subnet to its NSG
resource "azurerm_subnet_network_security_group_association" "bastion-nsg-assoc" {
  subnet_id                 = azurerm_subnet.bastion-subnet.id
  network_security_group_id = azurerm_network_security_group.bastion-nsg.id
}

resource "azurerm_nat_gateway" "vm-nat-gateway" {
  name                = "vm-nat-gateway"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  sku_name            = "Standard"
}

resource "azurerm_public_ip" "vm_nat_public_ip" {
  name                = "vm-nat-public-ip"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "vm_nat_assoc" {
  nat_gateway_id = azurerm_nat_gateway.vm-nat-gateway.id
  public_ip_address_id = azurerm_public_ip.vm_nat_public_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "vm_subnet_nat" {
  subnet_id      = azurerm_subnet.vm-subnet.id
  nat_gateway_id = azurerm_nat_gateway.vm-nat-gateway.id
}
