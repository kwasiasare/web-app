targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Project name for resource naming')
param projectName string = 'web-app'

@description('SQL Server administrator login name')
param sqlAdminUsername string = 'sqladmin'

@description('Object ID for Key Vault access policy')
param keyVaultAccessObjectId string

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

// Common variables
var environmentId = '${projectName}-${environment}'
var commonTags = {
  environment: environment
  project: projectName
  managedBy: 'bicep'
}

// Deploy networking infrastructure
module networking 'modules/networking.bicep' = {
  name: 'networking-deployment'
  params: {
    location: location
    environmentId: environmentId
    tags: commonTags
  }
}

// Deploy monitoring infrastructure
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    location: location
    environmentId: environmentId
    tags: commonTags
  }
}

// Deploy Key Vault
module security 'modules/security.bicep' = {
  name: 'security-deployment'
  params: {
    location: location
    environmentId: environmentId
    tags: commonTags
    keyVaultAccessObjectId: keyVaultAccessObjectId
    subnetId: networking.outputs.keyVaultSubnetId
  }
}

// Deploy SQL Database
module data 'modules/data.bicep' = {
  name: 'data-deployment'
  params: {
    location: location
    environmentId: environmentId
    tags: commonTags
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    subnetId: networking.outputs.databaseSubnetId
  }
  dependsOn: [
    networking
  ]
}

// Store SQL connection string in Key Vault
resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${security.outputs.keyVaultName}/sql-connection-string'
  properties: {
    value: 'Server=tcp:${data.outputs.sqlServerFqdn},1433;Initial Catalog=${data.outputs.sqlDatabaseName};Authentication=Active Directory Default;'
  }
  dependsOn: [
    security
    data
  ]
}

// Store Application Insights connection string in Key Vault
resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${security.outputs.keyVaultName}/appinsights-connection-string'
  properties: {
    value: monitoring.outputs.applicationInsightsConnectionString
  }
  dependsOn: [
    security
    monitoring
  ]
}

// Deploy Container Apps
module compute 'modules/compute.bicep' = {
  name: 'compute-deployment'
  params: {
    location: location
    environmentId: environmentId
    tags: commonTags
    subnetId: networking.outputs.containerAppSubnetId
    keyVaultName: security.outputs.keyVaultName
    workspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    networking
    security
    monitoring
    sqlConnectionStringSecret
    appInsightsConnectionStringSecret
  ]
}

// Deploy Static Web App
module web 'modules/web.bicep' = {
  name: 'web-deployment'
  params: {
    location: 'eastus2'
    environmentId: environmentId
    tags: commonTags
  }
}

// Configure RBAC for Container App managed identity
resource keyVaultSecretUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(security.outputs.keyVaultId, compute.outputs.containerAppIdentityPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: compute.outputs.containerAppIdentityPrincipalId
  }
}

resource sqlContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(data.outputs.sqlServerId, compute.outputs.containerAppIdentityPrincipalId, '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec') // SQL DB Contributor
    principalId: compute.outputs.containerAppIdentityPrincipalId
  }
}

// Outputs
output staticWebAppUrl string = web.outputs.staticWebAppUrl
output containerAppUrl string = compute.outputs.containerAppUrl
output keyVaultName string = security.outputs.keyVaultName
output sqlServerFqdn string = data.outputs.sqlServerFqdn