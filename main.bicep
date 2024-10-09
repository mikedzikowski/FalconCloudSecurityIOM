
targetScope = 'subscription'

@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The name of the resource group.')
param resourceGroupName string = 'rg-cs-cspm'

@description('The client ID for the Falcon API.')
param falconClientId string 

@description('The client secret for the Falcon API.')
@secure()
param falconClientSecret string

var keyVaultName = 'kv-cspm-${uniqueString(resourceGroupName)}'
var subscriptionId = subscription().subscriptionId


resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// Create App Registration in Azure AD with API Permissions for CrowdStrike
module appRegistration './modules/appRegistration.bicep' = {
  scope: subscription()
  name: 'appreg-deployment-${deploymentNameSuffix}'
  params: {
    appName: 'crowdstrike'
    deployEnvironment: 'cspm'
  }
  dependsOn: [
    rg
  ]
}

// Create Azure Account in CrowdStrike
module script './modules/azureAccount.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'cs-account-deployment-${deploymentNameSuffix}'
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    appRegistration: appRegistration.outputs.appId
  }
  dependsOn: [
    appRegistration
  ]
}

// Create Key Vault and upload certificate to Key Vault
module keyVault  './modules/keyVault.bicep' = { 
  scope: resourceGroup(rg.name)
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  params: {
    keyVaultName: keyVaultName
    skuName: 'standard'
    cspmCertificate: script.outputs.text
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
  }
  dependsOn: [
    script
  ]
}

// Add Certificate to App Registration 
module appCertificate './modules/secret.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'cert-deployment-${deploymentNameSuffix}'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    resourceGroupName: rg.name
    deploymentNameSuffix: deploymentNameSuffix
  }
  dependsOn: [
    appRegistration
    script
  ]
}

// Add the following roles to the App Registration in Azure AD
//'39bc4728-0917-49c7-9d2c-d95423bc2eb4' // Security Reader 
//'21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader
//'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader 
//'de139f84-1756-47ae-9be6-808fbbe84772' // Website Contributor 
//'7f6c6a51-bcf8-42ba-9220-52d62157d7db' // Azure Kubernetes Service RBAC Reader
module roleAssignment './modules/roleAssignment.bicep' = {
  name: 'role-deployment-${deploymentNameSuffix}'
  params: {
    principalId: appRegistration.outputs.principalId
  }
  dependsOn: [
    appRegistration
    keyVault
    script
  ]
}

output appRegistrationId string = appRegistration.outputs.appId
