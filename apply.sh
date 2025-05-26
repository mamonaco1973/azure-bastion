#!/bin/bash
#===============================================================================
# Master automation script for provisioning infrastructure, building VM images
# using Packer, and deploying resources with Terraform on Azure.
# Assumes the environment is pre-authenticated (e.g., via `az login`).
#===============================================================================

#-------------------------------------------------------------------------------
# STEP 0: Run environment validation script
#-------------------------------------------------------------------------------
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1  # Hard exit if environment validation fails
fi

#-------------------------------------------------------------------------------
# STEP 1: Provision base infrastructure (VNet, subnets, NICs, etc.)
#-------------------------------------------------------------------------------
cd 01-infrastructure                # Navigate to Terraform infra folder
terraform init                      # Initialize Terraform plugins/backend
terraform apply -auto-approve       # Apply infrastructure configuration without prompt
cd ..                               # Return to root directory

#-------------------------------------------------------------------------------
# STEP 2: Retrieve secret password for VM builds from Azure Key Vault
#-------------------------------------------------------------------------------
vault=$(az keyvault list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'packer-kv')].name | [0]" \
  --output tsv)                     # Get the first key vault name starting with 'packer-kv'

echo "NOTE: Key vault for secrets is $vault"

secretsJson=$(az keyvault secret show \
  --name packer-credentials \
  --vault-name ${vault} \
  --query value \
  -o tsv)                           # Retrieve JSON secret with credentials

password=$(echo "$secretsJson" | jq -r '.password')  # Extract `password` field from the secret JSON

#-------------------------------------------------------------------------------
# STEP 3A: Build custom LINUX image using Packer
#-------------------------------------------------------------------------------
cd 02-packer/linux                  # Enter Linux Packer template directory
packer init .                       # Initialize Packer plugins
packer build \
  -var="client_id=$ARM_CLIENT_ID" \
  -var="client_secret=$ARM_CLIENT_SECRET" \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="tenant_id=$ARM_TENANT_ID" \
  -var="password=$password" \
  -var="resource_group=packer-rg" \
  linux_image.pkr.hcl               # Packer HCL template for Linux image

cd ..                               # Return to 02-packer

#-------------------------------------------------------------------------------
# STEP 3B: Build custom WINDOWS image using Packer
#-------------------------------------------------------------------------------
cd windows                          # Enter Windows Packer template directory
packer init .                       # Initialize Packer plugins
packer build \
  -var="client_id=$ARM_CLIENT_ID" \
  -var="client_secret=$ARM_CLIENT_SECRET" \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="tenant_id=$ARM_TENANT_ID" \
  -var="password=$password" \
  -var="resource_group=packer-rg" \
  windows_image.pkr.hcl             # Packer HCL template for Windows image

cd ../..                            # Return to root

#-------------------------------------------------------------------------------
# STEP 4A: Identify the most recent custom image named "games_image*"
#-------------------------------------------------------------------------------
games_image_name=$(az image list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'games_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)                     # Grab the latest games_image by name sort

echo "NOTE: Using the latest image ($games_image_name) in packer-rg."

# Fail if image was not found
if [ -z "$games_image_name" ]; then
  echo "ERROR: No image with the prefix 'games_image' was found in the resource group 'packer-rg'. Exiting."
  exit 1
fi

#-------------------------------------------------------------------------------
# STEP 4B: Identify the most recent custom image named "desktop_image*"
#-------------------------------------------------------------------------------
desktop_image_name=$(az image list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'desktop_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)                     # Grab the latest desktop_image by name sort

echo "NOTE: Using the latest image ($desktop_image_name) in packer-rg."

# Fail if image was not found
if [ -z "$desktop_image_name" ]; then
  echo "ERROR: No image with the prefix 'desktop_image' was found in the resource group 'packer-rg'. Exiting."
  exit 1
fi

#-------------------------------------------------------------------------------
# STEP 5: Deploy final VM infrastructure using latest custom images
#-------------------------------------------------------------------------------
cd 03-deploy                        # Navigate to deployment Terraform folder
terraform init                      # Initialize Terraform
terraform apply \
  -var="games_image_name=$games_image_name" \
  -var="desktop_image_name=$desktop_image_name" \
  -auto-approve                     # Skip confirmation prompts
cd ..                               # Return to root directory

#-------------------------------------------------------------------------------
# END OF SCRIPT
#-------------------------------------------------------------------------------
