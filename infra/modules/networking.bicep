@description('Azure region for resource deployment')
param location string

@description('Environment identifier for resource naming')
param environmentId string

@description('Resource tags')
param tags object

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-${environmentId}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'containerapp-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'database-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'keyvault-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
    ]
  }
}

// Private DNS Zone for SQL
resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: tags
}

// Link DNS Zone to VNet
resource sqlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlPrivateDnsZone
  name: 'link-${environmentId}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Outputs
output vnetId string = vnet.id
output containerAppSubnetId string = vnet.properties.subnets[0].id
output databaseSubnetId string = vnet.properties.subnets[1].id
output keyVaultSubnetId string = vnet.properties.subnets[2].id
output sqlPrivateDnsZoneId string = sqlPrivateDnsZone.id