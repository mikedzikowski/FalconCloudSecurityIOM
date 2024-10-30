
param userAssignedIdentity string
param storageAccountName string
param keyName string
param keyVaultUri string
param location string = resourceGroup().location
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    encryption: {
      identity: {
        userAssignedIdentity: userAssignedIdentity
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: keyName
        keyvaulturi: keyVaultUri
      }
    }
  }
}
