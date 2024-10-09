param keyVaultName string
param location string = resourceGroup().location
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'
@secure()
param cspmCertificate string
param falconClientId string
@secure()
param falconClientSecret string
// @description('The suffix to be added to the deployment name.')
// param deploymentNameSuffix string = utcNow()

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
  }
    publicNetworkAccess: 'Enabled'
  }
}

resource cert 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'falcon-cspm-certificate'
  properties: {
    value: cspmCertificate
  }
}

resource clientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'falcon-client-id'
  properties: {
    value: falconClientId
  }
}

resource clientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'falcon-client-secret'
  properties: {
    value: falconClientSecret
  }
}

output keyVaultName string = keyVault.name
output keyVaultResourceId string = keyVault.id
