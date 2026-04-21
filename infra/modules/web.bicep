@description('Azure region for resource deployment')
param location string

@description('Environment identifier for resource naming')
param environmentId string

@description('Resource tags')
param tags object

// Static Web App
resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: 'swa-${environmentId}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// Outputs
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output staticWebAppId string = staticWebApp.id