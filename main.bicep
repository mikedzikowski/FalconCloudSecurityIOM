
targetScope = 'subscription'

@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The name of the resource group.')
param resourceGroupName string = 'rg-cspm-demo-2'

@description('The client ID for the Falcon API.')
param falconClientId string 

@description('The client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('The app registration ID for the Azure AD application.')
param appRegistrationAppId string

@description('The name of the user-assigned managed identity.')
param uamiName string
param deployIOA bool = false

var keyVaultName = 'kv-cspm-${uniqueString(resourceGroupName)}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
  scope: resourceGroup(rg.name)
    name: uamiName
}

// Create Azure Account in CrowdStrike
module script './modules/azureAccount.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'cs-account-deployment-${deploymentNameSuffix}'
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    appRegistration: appRegistrationAppId
  }
}

// Create Key Vault and upload certificate to Key Vault
module keyVault  './modules/keyVault.bicep' = { 
  scope: resourceGroup(rg.name)
  name: 'cs-keyvault-deployment-${deploymentNameSuffix}'
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

// ADD CERTIFICATE TO REGISTRATION USING DEPLOYMENT SCRIPT 
module certificate './modules/certificate.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'cs-cert-deployment-${deploymentNameSuffix}'
  params: {
    location: location
    appRegistrationId: appRegistrationAppId
    cspmCertificate: script.outputs.text
    userAssignedIdentityName: uami.name
    userAssignedIdentityResourceGroupName: split(uami.id, '/')[4]
  }
  dependsOn: [
    keyVault
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
  name: 'cs-role-${deploymentNameSuffix}'
  params: {
    principalId: appRegistrationAppId
  }
  dependsOn: [
    keyVault
    script
    certificate
  ]
}

output deployIOA bool = deployIOA
