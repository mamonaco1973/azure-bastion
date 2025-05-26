############################################
# INPUT VARIABLE: CUSTOM IMAGE NAME LINUX
############################################
variable "games_image_name" {
  description = "Name of the custom Azure linux image"   # Human-readable explanation of the variable's purpose
  type        = string                                   # Enforce the input type as a string (required for validation and clarity)
                                                         # This value is typically passed in via CLI, tfvars, or environment
}
############################################
# INPUT VARIABLE: CUSTOM IMAGE NAME WINDOWS
############################################
variable "desktop_image_name" {
  description = "Name of the custom Azure windows image"   # Human-readable explanation of the variable's purpose
  type        = string                                     # Enforce the input type as a string (required for validation and clarity)
                                                           # This value is typically passed in via CLI, tfvars, or environment
}

############################################
# VARIABLES: NETWORK NAMES WITH DEFAULTS
############################################

variable "vnet_name" {
  description = "Name of the existing virtual network"
  type        = string
  default     = "packer-vnet"                     # Default value matches previous hardcoded value
}

variable "subnet_name" {
  description = "Name of the existing subnet"
  type        = string
  default     = "packer-subnet"                   # Default value matches previous hardcoded value
}

############################################
# VARIABLE: RESOURCE GROUP NAME WITH DEFAULT
############################################

variable "resource_group_name" {
  description = "Name of the existing resource group used for image and network"
  type        = string
  default     = "packer-rg"                         # Default value matches the original hardcoded value
}
