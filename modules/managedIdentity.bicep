targetScope = 'resourceGroup'
param location string = resourceGroup().location

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'myUserManagedIdentity'
  location: location
}

output principalId string = userIdentity.properties.principalId
output clientId string = userIdentity.properties.clientId
output id string = userIdentity.id
