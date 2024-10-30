param userAssignedIdentityName string
param storageAccountName string
param keyVaultName string
param keyVaultCryptoOfficerRoleId string = '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
param storageAccountSubnetId string
param storagePrivateEndpointName string
param storagePrivateEndpointConnectionName string
param storagePrivateEndpointSubnetId string
param location string = resourceGroup().location
param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: location
  tags: tags
}

resource storageAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('keyVault', userAssignedIdentity.id, keyVaultCryptoOfficerRoleId)
  scope: keyVault
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultCryptoOfficerRoleId)
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    allowBlobPublicAccess: false

    encryption: {
      requireInfrastructureEncryption: true
    }
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices, Logging, Metrics'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: storageAccountSubnetId
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
  dependsOn: [
    storageAccountRoleAssignment
  ]
}

resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 1
    }
    #disable-next-line BCP037
    logging: {
      read: true
      write: true
      delete: true
      retentionPolicy: {
        enabled: true
        days: 7
      }
      version: '1.0'
    }
  }
}

resource storageAccountQueueService 'Microsoft.Storage/storageAccounts/queueServices@2021-09-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    #disable-next-line BCP037
    logging: {
      read: true
      write: true
      delete: true
      retentionPolicy: {
        enabled: true
        days: 7
      }
      version: '1.0'
    }
  }
}

resource storageAccountTableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    #disable-next-line BCP037
    logging: {
      read: true
      write: true
      delete: true
      retentionPolicy: {
        enabled: true
        days: 7
      }
      version: '1.0'
    }
  }
}

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: storagePrivateEndpointName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: storagePrivateEndpointConnectionName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: storagePrivateEndpointSubnetId
    }
  }
}

output userAssignedIdentityId string = userAssignedIdentity.id
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
