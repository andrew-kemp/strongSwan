@description('Name of the Virtual Network. If not provided, a new VNet will be created.')
param vnetName string = ''
@description('Resource group of the existing VNet, if using an existing one.')
param vnetResourceGroup string = ''
@description('Name of the subnet. If not provided, a new subnet will be created.')
param subnetName string = ''
@description('VM name')
param vmName string = 'ubuntu-vm'
@description('Admin username')
param adminUsername string
@secure()
@description('Admin password')
param adminPassword string

var location = resourceGroup().location

// Create a VNet if not using an existing one
resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = if (empty(vnetName)) {
  name: '${vmName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: '${vmName}-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// Get reference to existing VNet if supplied
resource existingVnet 'Microsoft.Network/virtualNetworks@2023-02-01' existing = if (!empty(vnetName)) {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

// Subnet resource reference
var subnetResourceId = empty(vnetName)
  ? vnet.properties.subnets[0].id
  : resourceId(vnetResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

// Create NIC with IP forwarding enabled
resource nic 'Microsoft.Network/networkInterfaces@2023-02-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetResourceId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableIPForwarding: true
  }
}

// Ubuntu image reference (latest LTS)
var ubuntuImage = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// VM resource
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// NSG for custom UDP rules
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-UDP-500'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '500'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-UDP-4500'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '4500'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1002
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-02-01' = {
  // ... (as before)
  properties: {
    // ...
    networkSecurityGroup: {
      id: nsg.id
    }
    enableIPForwarding: true
  }
}
