#!/bin/bash
#===============================================================================
# SCRIPT: Destroy Terraform Infrastructure and Delete Custom Azure Images
#===============================================================================
# This script performs the following steps:
#   1. Authenticates to Azure using a service principal
#   2. Retrieves the most recent custom VM images for 'games' and 'desktop'
#   3. Destroys the deployed infrastructure using those images
#   4. Deletes all VM images from the 'packer-rg' resource group
#   5. Destroys base infrastructure (networking, etc.)
#===============================================================================

#-------------------------------------------------------------------------------
# STEP 1: Azure CLI Login using a Service Principal (suppress output)
#-------------------------------------------------------------------------------
az login \
  --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant "$ARM_TENANT_ID" \
  > /dev/null 2>&1   # Silence all output to avoid leaking credentials or clutter

#-------------------------------------------------------------------------------
# STEP 2A: Fetch latest 'games_image' from the packer resource group
#-------------------------------------------------------------------------------
games_image_name=$(az image list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'games_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using the latest image ($games_image_name) in packer-rg."

# Fail-fast if no games_image is found
if [ -z "$games_image_name" ]; then
  echo "ERROR: No image with the prefix 'games_image' was found in 'packer-rg'. Exiting."
  exit 1
fi

#-------------------------------------------------------------------------------
# STEP 2B: Fetch latest 'desktop_image' from the packer resource group
#-------------------------------------------------------------------------------
desktop_image_name=$(az image list \
  --resource-group packer-rg \
  --query "[?starts_with(name, 'desktop_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using the latest image ($desktop_image_name) in packer-rg."

# Fail-fast if no desktop_image is found
if [ -z "$desktop_image_name" ]; then
  echo "ERROR: No image with the prefix 'desktop_image' was found in 'packer-rg'. Exiting."
  exit 1
fi

#-------------------------------------------------------------------------------
# STEP 3: Destroy all VMs and attached resources deployed in phase 03
#-------------------------------------------------------------------------------
cd 03-deploy                         # Navigate to the final deployment folder
terraform init                      # Re-initialize Terraform plugins/backend
terraform destroy \
  -var="games_image_name=$games_image_name" \
  -var="desktop_image_name=$desktop_image_name" \
  -auto-approve                     # Skip prompts for automation
cd ..                               # Return to project root

#-------------------------------------------------------------------------------
# STEP 4: Loop through and delete ALL images in 'packer-rg' (fire-and-forget)
#-------------------------------------------------------------------------------
az image list \
  --resource-group "packer-rg" \
  --query "[].name" \
  -o tsv | while read -r IMAGE; do
    echo "Deleting image: $IMAGE"
    az image delete \
      --name "$IMAGE" \
      --resource-group "packer-rg" \
      || echo "Failed to delete $IMAGE — skipping"
done

#-------------------------------------------------------------------------------
# STEP 5: Destroy base infrastructure (VNet, Subnet, NICs, NSGs, etc.)
#-------------------------------------------------------------------------------
cd 01-infrastructure                # Go to base infra config
terraform init                     # Initialize Terraform plugins/modules
terraform destroy -auto-approve    # Destroy all foundational Azure resources
cd ..                              # Return to root

#-------------------------------------------------------------------------------
# END OF SCRIPT
#-------------------------------------------------------------------------------
