targetScope = 'subscription'

param principalId string

var roleDefinitionIds = [
  '39bc4728-0917-49c7-9d2c-d95423bc2eb4' // Security Reader | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#automation-contributor
  '21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader| https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader
  'de139f84-1756-47ae-9be6-808fbbe84772' // Website Contributor | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  '7f6c6a51-bcf8-42ba-9220-52d62157d7db' // Azure Kubernetes Service RBAC Reader | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(principalId, roleDefinitionId, subscription().subscriptionId)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
