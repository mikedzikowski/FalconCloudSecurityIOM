
targetScope = 'subscription'

@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The suffix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-ioa'

@description('The name of the resource group.')
param iomResourceGroupName string = 'cs-iom-group'

@description('The name of the resource group.')
param ioaResourceGroupName string = 'cs-ioa-group'

@description('The client ID for the Falcon API.')
param falconClientId string 

@description('The client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('The CID for the Falcon API.')
param falconCID string

@description('The app registration ID for the Azure AD application.')
param appRegistrationAppId string

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'cstag-product': 'fcs'
  'cstag-purpose': 'cspm'
}

@description('The name of the user-assigned managed identity.')
param uamiName string

@description('The resource Id of the user-assigned managed identity.')
param uamiResourceId string

param deployIOA bool = false

param randomSuffix string = uniqueString(ioaResourceGroupName)

@description('The array of policy assignment IDs to exempt to prevent issues with the build process.')
param exemptPolicyAssignmentIds array = []

@description('The Falcon cloud region.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'
@description('Deploy Activity Log Diagnostic Settings')
param deployActivityLogDiagnosticSettings bool = false
@description('Deploy Entra Log Diagnostic Settings')
param deployEntraLogDiagnosticSettings bool = false

/* Variables */ 

/* ParameterBag for CS Logs */
var csLogSettings = {
  storageAccountName: substring('cshorizonlogs${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonlogs${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'log-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-log-storage-private-endpoint'
}

/* ParameterBag for Activity Logs */
var activityLogSettings = {
  hostingPlanName: 'cs-activity-service-plan'
  functionAppName: 'cs-activity-func-${subscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppIdentityName: 'cs-activity-func-${subscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppDiagnosticSettingName: 'cs-activity-func-to-storage'
  ioaPackageURL: 'https://cs-prod-cloudconnect-templates.s3-us-west-1.amazonaws.com/azure/4.x/ioa.zip'
  storageAccountName: substring('cshorizonact${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonact${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'activity-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-activity-storage-private-endpoint'
  eventHubName: 'cs-eventhub-monitor-activity-logs' // DO NOT CHANGE - used for registration validation
  diagnosticSetttingsName: 'cs-monitor-activity-to-eventhub' // DO NOT CHANGE - used for registration validation
}

/* ParameterBag for EntraId Logs */
var entraLogSettings = {
  hostingPlanName: 'cs-aad-service-plan'
  functionAppName: 'cs-aad-func-${subscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppIdentityName: 'cs-aad-func-${subscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppDiagnosticSettingName: 'cs-aad-func-to-storage'
  ioaPackageURL: 'https://cs-prod-cloudconnect-templates.s3-us-west-1.amazonaws.com/azure/4.x/ioa.zip'
  storageAccountName: substring('cshorizonaad${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonaad${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'aad-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-aad-storage-private-endpoint'
  eventHubName: 'cs-eventhub-monitor-aad-logs' // DO NOT CHANGE - used for registration validation
  diagnosticSetttingsName: 'cs-aad-to-eventhub' // DO NOT CHANGE - used for registration validation
}

var subscriptionId = subscription().subscriptionId
var ioaKeyVaultName = 'kv-ioa-${uniqueString(ioaResourceGroupName)}'
var iomKeyVaultName = 'kv-iom-${uniqueString(iomResourceGroupName)}'
var eventHubNamespaceName = 'cs-horizon-ns-${subscriptionId}' // DO NOT CHANGE - used for registration validation
var virtualNetworkName = 'cs-vnet'

module policyExemptions './modules/exemptions.bicep' = [
  for i in range(0, length(exemptPolicyAssignmentIds)): if (!empty((exemptPolicyAssignmentIds)[0])) {
    name: 'PolicyExemption_${i}'
    scope: resourceGroup(subscriptionId, iomRg.name)
    params: {
      policyAssignmentId: exemptPolicyAssignmentIds[i]
    }
  }
]


resource iomRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: iomResourceGroupName
  location: location
}

resource ioaRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: ioaResourceGroupName
  location: location
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
    scope: resourceGroup(split(uamiResourceId, '/')[4])
    name: uamiName
}

// Create Azure Account in CrowdStrike
module script './modules/azureAccount.bicep' = {
  scope: resourceGroup(iomRg.name)
  name: 'cs-iom-account-deployment-${deploymentNameSuffix}'
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    appRegistration: appRegistrationAppId
    subscriptionId: subscriptionId
  }
  dependsOn: [
    policyExemptions
  ]
}

module iomKeyVault './modules/iomKeyVault.bicep' = {
  scope: resourceGroup(iomRg.name)
  name: 'cs-iom-keyvault-deployment-${deploymentNameSuffix}'
  params: {
    keyVaultName: iomKeyVaultName
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    cspmCertificate: script.outputs.text
  }
  dependsOn: [
    policyExemptions]
}


// ADD CERTIFICATE TO REGISTRATION USING DEPLOYMENT SCRIPT 
module certificate './modules/certificate.bicep' = {
  scope: resourceGroup(iomRg.name)
  name: 'cs-iom-cert-deployment-${deploymentNameSuffix}'
  params: {
    location: location
    appRegistrationId: appRegistrationAppId
    cspmCertificate: script.outputs.text
    userAssignedIdentityName: uami.name
    userAssignedIdentityResourceGroupName: split(uami.id, '/')[4]
  }
  dependsOn: [
    iomKeyVault
    policyExemptions
  ]
}

// Add the following roles to the App Registration in Azure AD
//'39bc4728-0917-49c7-9d2c-d95423bc2eb4' // Security Reader 
//'21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader
//'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader 
//'de139f84-1756-47ae-9be6-808fbbe84772' // Website Contributor 
//'7f6c6a51-bcf8-42ba-9220-52d62157d7db' // Azure Kubernetes Service RBAC Reader
module roleAssignment './modules/roleAssignment.bicep' = {
  name: 'cs-iom-role-${deploymentNameSuffix}'
  params: {
    principalId: appRegistrationAppId
  }
  dependsOn: [
    iomKeyVault
    script
    certificate
    policyExemptions
  ]
}


// IOA Deployment - Create resources for IOA if deployIOA is true

// Create Key Vault and upload certificate to Key Vault
module keyVault './modules/keyVault.bicep'= if (deployIOA) { 
  scope: resourceGroup(ioaRg.name)
  name: 'cs-ioa-keyvault-deployment-${deploymentNameSuffix}'
  params: {
    keyVaultName:  deployIOA ? ioaKeyVaultName : 'None'
    falconClientId: deployIOA ? falconClientId : 'None'
    falconClientSecret: deployIOA ? falconClientSecret : 'None'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'None'
  }
  dependsOn: [
    virtualNetwork
    policyExemptions
  ]
}

// Create Virtual Network for secure communication of services
module virtualNetwork './modules/virtualNetwork.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-virtualNetwork-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    virtualNetworkName: deployIOA ? virtualNetworkName : 'None'
    tags: tags
  }
}

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'modules/eventHub.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-eventHubs-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    eventHubNamespaceName: deployIOA ? eventHubNamespaceName : 'None'
    activityLogEventHubName: deployIOA ? activityLogSettings.eventHubName : 'None'
    entraLogEventHubName: deployIOA ? entraLogSettings.eventHubName : 'None'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'None'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create CrowdStrike Log Storage Account */
module csLogStorage 'modules/storageAccount.bicep' = if (deployIOA) {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-csLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: deployIOA ? csLogSettings.storageAccountIdentityName : 'None'
    storageAccountName: deployIOA ? csLogSettings.storageAccountName : 'None'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'None'
    storageAccountSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet1Id : 'None'
    storagePrivateEndpointName: deployIOA ? csLogSettings.storagePrivateEndpointName : 'None'
    storagePrivateEndpointConnectionName: deployIOA ? csLogSettings.storagePrivateEndpointConnectionName : 'None'
    storagePrivateEndpointSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet3Id : 'None'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Enable CrowdStrike Log Storage Account Encryption */
module csLogStorageEncryption 'modules/enableEncryption.bicep' = if (deployIOA) { 
  name: '${deploymentNamePrefix}-csLogStorageEncryption-${deploymentNameSuffix}'
  scope: resourceGroup(ioaResourceGroupName)
  params: {
    userAssignedIdentity: deployIOA ? csLogStorage.outputs.userAssignedIdentityId : 'None'
    storageAccountName: deployIOA ? csLogStorage.outputs.storageAccountName : 'None'
    keyName: deployIOA ? keyVault.outputs.csLogStorageKeyName : 'None'
    keyVaultUri: deployIOA ? keyVault.outputs.keyVaultUri : 'None'
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create KeyVault Diagnostic Setting to CrowdStrike Log Storage Account */
module keyVaultDiagnosticSetting 'modules/keyVaultDiagnosticSetting.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-keyVaultDiagnosticSetting-${deploymentNameSuffix}'
  scope: resourceGroup(ioaResourceGroupName)
  params: {
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'None'
    storageAccountName: deployIOA ? csLogStorage.outputs.storageAccountName : 'None'
  }
  dependsOn: [
    csLogStorage
    csLogStorageEncryption
    policyExemptions
  ]
}

/* Create Activity Log Diagnostic Storage Account */
module activityLogStorage 'modules/storageAccount.bicep' =if (deployIOA)  {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-activityLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: deployIOA ? activityLogSettings.storageAccountIdentityName : 'None'
    storageAccountName: deployIOA ? activityLogSettings.storageAccountName : 'None'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'None'
    storageAccountSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet1Id : 'None'
    storagePrivateEndpointName: deployIOA ? activityLogSettings.storagePrivateEndpointName : 'None'
    storagePrivateEndpointConnectionName:deployIOA ? activityLogSettings.storagePrivateEndpointConnectionName : 'None'
    storagePrivateEndpointSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet3Id : 'None'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Enable Activity Log Diagnostic Storage Account Encryption */
module activityLogStorageEncryption 'modules/enableEncryption.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-activityLogStorageEncryption-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    userAssignedIdentity: deployIOA ?  activityLogStorage.outputs.userAssignedIdentityId : 'None'
    storageAccountName: deployIOA ? activityLogStorage.outputs.storageAccountName : 'None'
    keyName: deployIOA ? keyVault.outputs.activityLogStorageKeyName : 'None'
    keyVaultUri: deployIOA ? keyVault.outputs.keyVaultUri : 'None'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create Entra ID Log Diagnostic Storage Account */
module entraLogStorage 'modules/storageAccount.bicep' = if (deployIOA) {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-entraLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: deployIOA ? entraLogSettings.storageAccountIdentityName : 'None'
    storageAccountName: deployIOA ? entraLogSettings.storageAccountName : 'None'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'None'
    storageAccountSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet2Id : 'None'
    storagePrivateEndpointName: deployIOA ? entraLogSettings.storagePrivateEndpointName : 'None'
    storagePrivateEndpointConnectionName: deployIOA ? entraLogSettings.storagePrivateEndpointConnectionName : 'None'
    storagePrivateEndpointSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet3Id : 'None'
    tags: deployIOA? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Enable Entra ID Log Diagnostic Storage Account Encryption */
module entraLogStorageEncryption 'modules/enableEncryption.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-entraLogStorageEncryption-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    userAssignedIdentity: deployIOA ? entraLogStorage.outputs.userAssignedIdentityId : 'None'
    storageAccountName: deployIOA ? entraLogStorage.outputs.storageAccountName : 'None'
    keyName: deployIOA ? keyVault.outputs.activityLogStorageKeyName : 'None'
    keyVaultUri: deployIOA ? keyVault.outputs.keyVaultUri : 'None'
    tags: deployIOA ? tags: {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create User-Assigned Managed Identity for Activity Log Diagnostic Function */
module activityLogFunctionIdentity 'modules/functionIdentity.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-activityLogFunctionIdentity-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    functionAppIdentityName: deployIOA ? activityLogSettings.functionAppIdentityName : 'None'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'None'
    storageAccountName: deployIOA ? activityLogSettings.storageAccountName : 'None'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'None'
    tags: deployIOA ? tags : {} 
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
    policyExemptions
  ]
}

/* Create Azuure Function to forward Activity Logs to CrowdStrike */
module activityLogFunction 'modules/functionApp.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-activityLogFunction-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    hostingPlanName: deployIOA ? activityLogSettings.hostingPlanName : 'None'
    functionAppName: deployIOA ? activityLogSettings.functionAppName : 'None'
    functionAppIdentityName: deployIOA ? activityLogFunctionIdentity.outputs.functionIdentityName : 'None'
    packageURL: deployIOA ? activityLogSettings.ioaPackageURL : 'None'
    storageAccountName: deployIOA ? activityLogSettings.storageAccountName : 'None'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'None'
    eventHubName: deployIOA ? activityLogSettings.eventHubName : 'None'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'None'
    virtualNetworkSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet1Id : 'None'
    diagnosticSettingName: deployIOA ? activityLogSettings.functionAppDiagnosticSettingName : 'None'
    csCID: deployIOA ? falconCID : 'None'
    csClientIdUri: deployIOA ? keyVault.outputs.csClientIdUri : 'None'
    csClientSecretUri: deployIOA ? keyVault.outputs.csClientSecretUri : 'None'
    tags: deployIOA ? tags  : {}
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
    activityLogFunctionIdentity
    policyExemptions
  ]
}

/* Create User-Assigned Managed Identity for Entra ID Log Diagnostic Function */
module entraLogFunctionIdentity 'modules/functionIdentity.bicep' = if (deployIOA)  {
  name: '${deploymentNamePrefix}-entraLogFunctionIdentity-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    functionAppIdentityName: deployIOA ? entraLogSettings.functionAppIdentityName: 'None'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'None'
    storageAccountName: deployIOA ? entraLogSettings.storageAccountName : 'None'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'None'
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
    policyExemptions
  ]
}

/* Create Azuure Function to forward Entra ID Logs to CrowdStrike */
module entraLogFunction 'modules/functionApp.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-entraLogFunction-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    hostingPlanName: deployIOA ? entraLogSettings.hostingPlanName : 'None'
    functionAppName: deployIOA ? entraLogSettings.functionAppName : 'None'
    functionAppIdentityName: deployIOA ? entraLogFunctionIdentity.outputs.functionIdentityName : 'None'
    packageURL: deployIOA ? entraLogSettings.ioaPackageURL : 'None'
    storageAccountName: deployIOA ? entraLogSettings.storageAccountName : 'None'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'None'
    eventHubName: deployIOA ? entraLogSettings.eventHubName : 'None'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'None'
    virtualNetworkSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet2Id : 'None'
    diagnosticSettingName: deployIOA ? entraLogSettings.functionAppDiagnosticSettingName : 'None'
    csCID: deployIOA ? falconCID : 'None'
    csClientIdUri: deployIOA ?  keyVault.outputs.csClientIdUri : 'None'
    csClientSecretUri:  deployIOA ? keyVault.outputs.csClientSecretUri : 'None'
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
    entraLogFunctionIdentity
    policyExemptions
  ]
}

/* 
  Deploy Diagnostic Settings for Azure Activity Logs - current Azure subscription

  Collect Azure Activity Logs and submit them to CrowdStrike for analysis of Indicators of Attack (IOA)

  Note:
   - 'Contributor' permissions are required to create Azure Activity Logs diagnostic settings
*/
resource activityDiagnosticSetttings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployActivityLogDiagnosticSettings && deployIOA) {
  name: activityLogSettings.diagnosticSetttingsName
  properties: {
    eventHubAuthorizationRuleId: (deployIOA && deployActivityLogDiagnosticSettings) ? eventHub.outputs.eventHubAuthorizationRuleId : 'None'
    eventHubName: (deployIOA && deployActivityLogDiagnosticSettings) ? activityLogSettings.eventHubName : 'None'
    logs: [
      {
        category: 'Administrative'
        enabled: true
      }
      {
        category: 'Security'
        enabled: true
      }
      {
        category: 'ServiceHealth'
        enabled: true
      }
      {
        category: 'Alert'
        enabled: true
      }
      {
        category: 'Recommendation'
        enabled: true
      }
      {
        category: 'Policy'
        enabled: true
      }
      {
        category: 'Autoscale'
        enabled: true
      }
      {
        category: 'ResourceHealth'
        enabled: true
      }
    ]
  }
}

/* 
  Deploy Diagnostic Settings for Microsoft Entra ID Logs

  Collect Microsoft Entra ID logs and submit them to CrowdStrike for analysis of Indicators of Attack (IOA)

  Note:
   - To export SignInLogs a P1 or P2 Microsoft Entra ID license is required
   - 'Security Administrator' or 'Global Administrator' Entra ID permissions are required
*/
// resource entraDiagnosticSetttings 'microsoft.aadiam/diagnosticSettings@2017-04-01' = if (deployEntraLogDiagnosticSettings && deployIOA) {
//   name: entraLogSettings.diagnosticSetttingsName
//   scope: tenant()
//   properties: {
//     eventHubAuthorizationRuleId: eventHub.outputs.eventHubAuthorizationRuleId
//     eventHubName: activityLogSettings.eventHubName
//     logs: [
//       {
//         category: 'AuditLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//       {
//         category: 'SignInLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//       {
//         category: 'NonInteractiveUserSignInLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//       {
//         category: 'ServicePrincipalSignInLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//       {
//         category: 'ManagedIdentitySignInLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//       {
//         category: 'ADFSSignInLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//     ]
//   }
// }

/* Set CrowdStrike CSPM Default Azure Subscription */
module setAzureDefaultSubscription './modules/defaultSubscription.bicep' = if (deployIOA) {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-defaultSubscription-${deploymentNameSuffix}'
  params: {
    falconClientId: deployIOA ? falconClientId : 'None'
    falconClientSecret: deployIOA ? falconClientSecret : 'None'
    falconCloudRegion: deployIOA ? falconCloudRegion : 'US-1'
    tags: tags
  }
  dependsOn: [
    script
    certificate
    policyExemptions
  ]
}

/* Deployment outputs required for follow-up activities */
output eventHubAuthorizationRuleId string = deployIOA ? eventHub.outputs.eventHubAuthorizationRuleId : 'None'
output activityLogEventHubName string = deployIOA ? eventHub.outputs.activityLogEventHubName: 'None'
output entraLogEventHubName string = deployIOA ? eventHub.outputs.entraLogEventHubName: 'None'
