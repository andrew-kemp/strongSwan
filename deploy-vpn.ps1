# Login & Subscription selection
az login
$subscriptions = az account list --query '[].{name:name, id:id}' -o table
$subs = az account list --query '[].name' -o tsv
for ($i=0; $i -lt $subs.Length; $i++) { Write-Host "$($i+1): $($subs[$i])" }
$subIdx = Read-Host "Select a subscription (number)"
$subName = $subs[$subIdx-1]
az account set --subscription "$subName"

# Resource group prompt
$rgAction = Read-Host "Type 'new' to create a resource group or 'existing' to use an existing one"
if ($rgAction -eq 'new') {
  $rgName = Read-Host "Enter new resource group name"
  $location = Read-Host "Enter Azure location (e.g. uksouth)"
  az group create --name $rgName --location $location
} else {
  $rgs = az group list --query '[].name' -o tsv
  for ($i=0; $i -lt $rgs.Length; $i++) { Write-Host "$($i+1): $($rgs[$i])" }
  $rgIdx = Read-Host "Select a resource group (number)"
  $rgName = $rgs[$rgIdx-1]
}

# Prompt for params
$adminUsername = Read-Host "Enter VM admin username"
$adminPassword = Read-Host -AsSecureString "Enter VM admin password"

$vnetChoice = Read-Host "Use existing VNet (yes/no)?"
if ($vnetChoice -eq 'yes') {
  $vnets = az network vnet list --resource-group $rgName --query '[].name' -o tsv
  for ($i=0; $i -lt $vnets.Length; $i++) { Write-Host "$($i+1): $($vnets[$i])" }
  $vnetIdx = Read-Host "Select a VNet (number)"
  $vnetName = $vnets[$vnetIdx-1]
  $subnets = az network vnet subnet list --resource-group $rgName --vnet-name $vnetName --query '[].name' -o tsv
  for ($i=0; $i -lt $subnets.Length; $i++) { Write-Host "$($i+1): $($subnets[$i])" }
  $subnetIdx = Read-Host "Select a Subnet (number)"
  $subnetName = $subnets[$subnetIdx-1]
} else {
  $vnetName = ""
  $subnetName = ""
}

$vmName = Read-Host "Enter VM name"

# Deploy Bicep
az deployment group create `
  --resource-group $rgName `
  --template-file main.bicep `
  --parameters vmName=$vmName adminUsername=$adminUsername adminPassword=$adminPassword vnetName=$vnetName subnetName=$subnetName
