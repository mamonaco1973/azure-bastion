############################################
#              PACKER SETUP
############################################

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"     # Official Azure plugin for Packer
      version = "~> 2"                            # Use version 2.x for stability
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"  # Enables patching via Windows Update
      version = "0.15.0"                          # Explicit version for consistency
    }
  }
}

############################################
#        LOCAL TIMESTAMP FOR IMAGE NAME
############################################

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "") # Format timestamp: YYYYMMDDHHMMSS
}

############################################
#           PARAMETER VARIABLES
############################################

variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "resource_group" {
  description = "Resource group where the VM image will be created"
  type        = string
}

variable "password" {
  description = "Administrator password for WinRM access"
  default     = ""
}

############################################
#     MAIN SOURCE BLOCK - AZURE WINDOWS VM
############################################

source "azure-arm" "desktop_image" {
  client_id            = var.client_id
  client_secret        = var.client_secret
  tenant_id            = var.tenant_id
  subscription_id      = var.subscription_id

  # Base image settings
  os_type              = "Windows"
  image_publisher      = "MicrosoftWindowsServer"
  image_offer          = "WindowsServer"
  image_sku            = "2022-Datacenter"
  location             = "Central US"
  vm_size              = "Standard_D2s_v3"                     # Similar to t3.medium

  # Target image settings
  managed_image_name   = "desktop_image_${local.timestamp}"
  managed_image_resource_group_name = var.resource_group

  # WinRM Configuration
  communicator         = "winrm"
  winrm_use_ssl        = true
  winrm_insecure       = true
  winrm_username       = "builder"
  winrm_password       = var.password
  
}

############################################
#             BUILD PROCESS
############################################

build {
  sources = ["source.azure-arm.desktop_image"]

  # Step 1: Apply Windows updates
  provisioner "windows-update" {}

  # Step 2: Reboot if needed post-updates
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Step 3: Run security hardening and user config
  provisioner "powershell" {
    script = "./security.ps1"
    environment_vars = [
      "PACKER_PASSWORD=${var.password}"
    ]
  }

  # Step 4: Create postbuild artifact directory
  provisioner "powershell" {
    inline = [
      "mkdir C:\\mcloud"
    ]
  }

  # Step 5: Upload boot configuration
  provisioner "file" {
    source      = "./boot.ps1"
    destination = "C:\\mcloud\\"
  }

  # Step 6-8: Install and configure Chrome, Firefox, and desktop icons
  provisioner "powershell" {
    script = "./chrome.ps1"
  }

  provisioner "powershell" {
    script = "./firefox.ps1"
  }

  provisioner "powershell" {
    script = "./desktop.ps1"
  }

  # Step 9: Sysprep using built-in tool
  provisioner "powershell" {
    inline = [
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet"
    ]
  }
}
