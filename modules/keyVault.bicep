param keyVaultName string
param location string = resourceGroup().location
param falconClientId string
@secure()
param falconClientSecret string
param virtualNetworkName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: virtualNetworkName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: {}
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [      ]
      virtualNetworkRules: [
        {
          id: virtualNetwork.properties.subnets[0].id
          ignoreMissingVnetServiceEndpoint: true
        }
        {
          id: virtualNetwork.properties.subnets[1].id
          ignoreMissingVnetServiceEndpoint: true
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource csLogStorageKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: 'cs-log-storage-key'
  tags: {}
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
    keySize: 4096
    kty: 'RSA'
  }
}

resource activityLogStorageKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: 'cs-activity-storage-key'
  tags: {}
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
    keySize: 4096
    kty: 'RSA'
  }
}

resource entraLogStorageKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: 'cs-aad-storage-key'
  tags: {}
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
    keySize: 4096
    kty: 'RSA'
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

resource csClientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'cs-client-id'
  tags: {}
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: falconClientId
  }
}

resource csClientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'cs-client-secret'
  tags: {}
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: falconClientSecret
  }
}

output keyVaultResourceId string = keyVault.id
output keyVaultName string = keyVault.name
output csLogStorageKeyName string = csLogStorageKey.name
output activityLogStorageKeyName string = activityLogStorageKey.name
output entraLogStorageKeyName string = entraLogStorageKey.name
output keyVaultUri string = keyVault.properties.vaultUri
output csClientIdUri string = csClientId.properties.secretUri
output csClientSecretUri string = csClientSecret.properties.secretUri
