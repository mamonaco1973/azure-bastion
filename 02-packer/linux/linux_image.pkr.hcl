############################################
# PACKER CONFIGURATION AND PLUGIN SETUP
############################################

packer {
  required_plugins {
    azure = {
      source   = "github.com/hashicorp/azure"            # Official Azure plugin for Packer
      version  = "~> 2"                                  # Lock to major version 2 for compatibility
    }
  }
}

############################################
# LOCALS: TIMESTAMP UTILITY
############################################

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "") # Generate compact timestamp (YYYYMMDDHHMMSS)
                                                       # Used for unique image names
}

############################################
# REQUIRED VARIABLES: AZURE CREDENTIALS
############################################

# Azure AD App client ID
variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

# Azure AD App client secret
variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
}

# Azure Subscription ID
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

# Azure Tenant ID (AAD directory ID)
variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

# Password passed into SSH config script (for enabling password auth)
variable "password" {
  description = "The password for the packer account"
  default     = ""                                       # Must be overridden securely via env var or CLI
}

variable "resource_group" {
  description = "Resource group where the VM image will be created"
  type        = string
}

############################################
# SOURCE BLOCK: AZURE CUSTOM IMAGE CREATION
############################################

source "azure-arm" "games_image" {
  client_id       = var.client_id                        # Auth: Azure AD App client ID
  client_secret   = var.client_secret                    # Auth: Azure AD App secret
  subscription_id = var.subscription_id                  # Auth: Azure subscription context
  tenant_id       = var.tenant_id                        # Auth: Azure AD tenant context

  # Base image to clone (Ubuntu 24.04 LTS)
  image_offer     = "ubuntu-24_04-lts"                   # Marketplace offer name
  image_publisher = "canonical"                          # Publisher: Canonical (Ubuntu)
  image_sku       = "server"                             # Image SKU: server edition
  
  ssh_username    = "ubuntu"                             # Username for the build

  location        = "Central US"                         # Azure region to build in
  vm_size         = "Standard_B1s"                       # Lightweight VM type for low-cost builds
  os_type         = "Linux"                              # Operating system type

  #os_disk_size_gb             = 64                      # Set OS disk size (in GB)
  #os_disk_managed_disk_type   = "Premium_LRS"           # Use Premium SSD for faster I/O

  managed_image_name                 = "games_image_${local.timestamp}"     # Unique image name using timestamp
  managed_image_resource_group_name = var.resource_group # RG where the custom image will be stored
}

############################################
# BUILD BLOCK: INSTALLATION & FILE COPY LOGIC
############################################

build {

  sources = ["source.azure-arm.games_image"]             # Link build block to source image definition

  # Step 1: Create temp working directory on image
  provisioner "shell" {
    inline = ["mkdir -p /tmp/html"]                      # Ensures destination path exists before file copy
  }

  # Step 2: Copy static site assets (HTML files) from local to the VM
  provisioner "file" {
    source      = "./html/"                              # Local directory with content
    destination = "/tmp/html/"                           # Target location on the image's disk
  }

  # Step 3: Run installation script to set up packages / web server
  provisioner "shell" {
    script = "./install.sh"                              # Custom provisioning script to install dependencies
  }

  # Step 4: Run SSH configuration script (enables password auth, etc.)
  provisioner "shell" {
    script = "./config_ssh.sh"                           # Custom script to tweak SSH server behavior
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"                  # Pass password into script securely as env var
    ]
  }
}
