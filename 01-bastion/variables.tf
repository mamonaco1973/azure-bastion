variable "project_resource_group" {
  description = "Name of the Azure Resource Group"
  default     = "bastion-rg"
  type        = string
}

variable "project_vnet" {
  description = "Name of the Azure Virtual Network"
  type        = string
  default     = "bastion-vnet"
}

variable "project_subnet" {
  description = "Name of the Azure Subnet within the Virtual Network"
  type        = string
  default     = "vm-subnet"
}


variable "project_location" {
  description = "Azure region where resources will be deployed (e.g., eastus, westeurope)"
  type        = string
  default     = "Central US"
}