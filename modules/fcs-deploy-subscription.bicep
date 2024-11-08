
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

param deployIOA bool
param deployIOM bool

param randomSuffix string = uniqueString(ioaResourceGroupName)

@description('The array of policy assignment IDs to exempt to prevent issues with the build process.')
param exemptPolicyAssignmentIds array = []

@description('The Falcon cloud region.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string
@description('Deploy Activity Log Diagnostic Settings')
param deployActivityLogDiagnosticSettings bool
@description('Deploy Entra Log Diagnostic Settings')
param deployEntraLogDiagnosticSettings bool
param targetManagementGroup bool

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

module policyExemptions 'exemptions.bicep' = [
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
module script './fcs-onboard-azure-account.bicep' = if (deployIOM) {
  scope: resourceGroup(iomRg.name)
  name: 'cs-iom-account-deployment-${deploymentNameSuffix}'
  params: {
    falconClientId: deployIOM ? falconClientId : 'none'
    falconClientSecret: deployIOM ? falconClientSecret : 'none'
    appRegistration: deployIOM ? appRegistrationAppId : 'none'
    subscriptionId: deployIOM ? subscriptionId : 'none'
  }
  dependsOn: [
    policyExemptions
  ]
}

module iomKeyVault './iomKeyVault.bicep' = if (deployIOM) {
  scope: resourceGroup(iomRg.name)
  name: 'cs-iom-keyvault-deployment-${deploymentNameSuffix}'
  params: {
    keyVaultName: deployIOM ? iomKeyVaultName : 'none'
    falconClientId: deployIOM ? falconClientId : 'none'
    falconClientSecret: deployIOM ? falconClientSecret : 'none'
    cspmCertificate: deployIOM ? script.outputs.text : 'none'
  }
  dependsOn: [
    policyExemptions
  ]
}

// ADD CERTIFICATE TO REGISTRATION USING DEPLOYMENT SCRIPT 
module certificate 'certificate.bicep' = if (deployIOM) {
  scope: resourceGroup(iomRg.name)
  name: 'cs-iom-cert-deployment-${deploymentNameSuffix}'
  params: {
    location: deployIOM ? location : 'none'
    appRegistrationId: deployIOM ? appRegistrationAppId : 'none'
    cspmCertificate: deployIOM ? script.outputs.text : 'none'
    userAssignedIdentityName: deployIOM ? uami.name : 'none'
    userAssignedIdentityResourceGroupName: deployIOM ? split(uami.id, '/')[4] : 'none'
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
module roleAssignment 'roleAssignment.bicep' = if (deployIOM) {
  name: 'cs-iom-role-${deploymentNameSuffix}'
  params: {
    principalId: deployIOM ? appRegistrationAppId : 'none'
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
module keyVault 'keyVault.bicep'= if (deployIOA) { 
  scope: resourceGroup(ioaRg.name)
  name: 'cs-ioa-keyvault-deployment-${deploymentNameSuffix}'
  params: {
    keyVaultName:  deployIOA ? ioaKeyVaultName : 'none'
    falconClientId: deployIOA ? falconClientId : 'none'
    falconClientSecret: deployIOA ? falconClientSecret : 'none'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'none'
  }
  dependsOn: [
    virtualNetwork
    policyExemptions
  ]
}

// Create Virtual Network for secure communication of services
module virtualNetwork 'virtualNetwork.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-virtualNetwork-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    virtualNetworkName: deployIOA ? virtualNetworkName : 'none'
    tags: tags
  }
}

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'eventHub.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-eventHubs-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    eventHubNamespaceName: deployIOA ? eventHubNamespaceName : 'none'
    activityLogEventHubName: deployIOA ? activityLogSettings.eventHubName : 'none'
    entraLogEventHubName: deployIOA ? entraLogSettings.eventHubName : 'none'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'none'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create CrowdStrike Log Storage Account */
module csLogStorage 'storageAccount.bicep' = if (deployIOA) {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-csLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: deployIOA ? csLogSettings.storageAccountIdentityName : 'none'
    storageAccountName: deployIOA ? csLogSettings.storageAccountName : 'none'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'none'
    storageAccountSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet1Id : 'none'
    storagePrivateEndpointName: deployIOA ? csLogSettings.storagePrivateEndpointName : 'none'
    storagePrivateEndpointConnectionName: deployIOA ? csLogSettings.storagePrivateEndpointConnectionName : 'none'
    storagePrivateEndpointSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet3Id : 'none'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Enable CrowdStrike Log Storage Account Encryption */
module csLogStorageEncryption 'enableEncryption.bicep' = if (deployIOA) { 
  name: '${deploymentNamePrefix}-csLogStorageEncryption-${deploymentNameSuffix}'
  scope: resourceGroup(ioaResourceGroupName)
  params: {
    userAssignedIdentity: deployIOA ? csLogStorage.outputs.userAssignedIdentityId : 'none'
    storageAccountName: deployIOA ? csLogStorage.outputs.storageAccountName : 'none'
    keyName: deployIOA ? keyVault.outputs.csLogStorageKeyName : 'none'
    keyVaultUri: deployIOA ? keyVault.outputs.keyVaultUri : 'none'
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create KeyVault Diagnostic Setting to CrowdStrike Log Storage Account */
module keyVaultDiagnosticSetting 'keyVaultDiagnosticSetting.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-keyVaultDiagnosticSetting-${deploymentNameSuffix}'
  scope: resourceGroup(ioaResourceGroupName)
  params: {
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'none'
    storageAccountName: deployIOA ? csLogStorage.outputs.storageAccountName : 'none'
  }
  dependsOn: [
    csLogStorage
    csLogStorageEncryption
    policyExemptions
  ]
}

/* Create Activity Log Diagnostic Storage Account */
module activityLogStorage 'storageAccount.bicep' =if (deployIOA)  {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-activityLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: deployIOA ? activityLogSettings.storageAccountIdentityName : 'none'
    storageAccountName: deployIOA ? activityLogSettings.storageAccountName : 'none'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'none'
    storageAccountSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet1Id : 'none'
    storagePrivateEndpointName: deployIOA ? activityLogSettings.storagePrivateEndpointName : 'none'
    storagePrivateEndpointConnectionName:deployIOA ? activityLogSettings.storagePrivateEndpointConnectionName : 'none'
    storagePrivateEndpointSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet3Id : 'none'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Enable Activity Log Diagnostic Storage Account Encryption */
module activityLogStorageEncryption 'enableEncryption.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-activityLogStorageEncryption-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    userAssignedIdentity: deployIOA ?  activityLogStorage.outputs.userAssignedIdentityId : 'none'
    storageAccountName: deployIOA ? activityLogStorage.outputs.storageAccountName : 'none'
    keyName: deployIOA ? keyVault.outputs.activityLogStorageKeyName : 'none'
    keyVaultUri: deployIOA ? keyVault.outputs.keyVaultUri : 'none'
    tags: deployIOA ? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create Entra ID Log Diagnostic Storage Account */
module entraLogStorage 'storageAccount.bicep' = if (deployIOA) {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-entraLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: deployIOA ? entraLogSettings.storageAccountIdentityName : 'none'
    storageAccountName: deployIOA ? entraLogSettings.storageAccountName : 'none'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'none'
    storageAccountSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet2Id : 'none'
    storagePrivateEndpointName: deployIOA ? entraLogSettings.storagePrivateEndpointName : 'none'
    storagePrivateEndpointConnectionName: deployIOA ? entraLogSettings.storagePrivateEndpointConnectionName : 'none'
    storagePrivateEndpointSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet3Id : 'none'
    tags: deployIOA? tags : {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Enable Entra ID Log Diagnostic Storage Account Encryption */
module entraLogStorageEncryption 'enableEncryption.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-entraLogStorageEncryption-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    userAssignedIdentity: deployIOA ? entraLogStorage.outputs.userAssignedIdentityId : 'none'
    storageAccountName: deployIOA ? entraLogStorage.outputs.storageAccountName : 'none'
    keyName: deployIOA ? keyVault.outputs.activityLogStorageKeyName : 'none'
    keyVaultUri: deployIOA ? keyVault.outputs.keyVaultUri : 'none'
    tags: deployIOA ? tags: {}
  }
  dependsOn: [
    policyExemptions
  ]
}

/* Create User-Assigned Managed Identity for Activity Log Diagnostic Function */
module activityLogFunctionIdentity 'functionIdentity.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-activityLogFunctionIdentity-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    functionAppIdentityName: deployIOA ? activityLogSettings.functionAppIdentityName : 'none'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'none'
    storageAccountName: deployIOA ? activityLogSettings.storageAccountName : 'none'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'none'
    tags: deployIOA ? tags : {} 
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
    policyExemptions
  ]
}

/* Create Azuure Function to forward Activity Logs to CrowdStrike */
module activityLogFunction 'functionApp.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-activityLogFunction-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    hostingPlanName: deployIOA ? activityLogSettings.hostingPlanName : 'none'
    functionAppName: deployIOA ? activityLogSettings.functionAppName : 'none'
    functionAppIdentityName: deployIOA ? activityLogFunctionIdentity.outputs.functionIdentityName : 'none'
    packageURL: deployIOA ? activityLogSettings.ioaPackageURL : 'none'
    storageAccountName: deployIOA ? activityLogSettings.storageAccountName : 'none'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'none'
    eventHubName: deployIOA ? activityLogSettings.eventHubName : 'none'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'none'
    virtualNetworkSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet1Id : 'none'
    diagnosticSettingName: deployIOA ? activityLogSettings.functionAppDiagnosticSettingName : 'none'
    csCID: deployIOA ? falconCID : 'none'
    csClientIdUri: deployIOA ? keyVault.outputs.csClientIdUri : 'none'
    csClientSecretUri: deployIOA ? keyVault.outputs.csClientSecretUri : 'none'
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
module entraLogFunctionIdentity 'functionIdentity.bicep' = if (deployIOA)  {
  name: '${deploymentNamePrefix}-entraLogFunctionIdentity-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    functionAppIdentityName: deployIOA ? entraLogSettings.functionAppIdentityName: 'none'
    keyVaultName: deployIOA ? keyVault.outputs.keyVaultName : 'none'
    storageAccountName: deployIOA ? entraLogSettings.storageAccountName : 'none'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'none'
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
    policyExemptions
  ]
}

/* Create Azuure Function to forward Entra ID Logs to CrowdStrike */
module entraLogFunction 'functionApp.bicep' = if (deployIOA) {
  name: '${deploymentNamePrefix}-entraLogFunction-${deploymentNameSuffix}'
  scope: resourceGroup(ioaRg.name)
  params: {
    hostingPlanName: deployIOA ? entraLogSettings.hostingPlanName : 'none'
    functionAppName: deployIOA ? entraLogSettings.functionAppName : 'none'
    functionAppIdentityName: deployIOA ? entraLogFunctionIdentity.outputs.functionIdentityName : 'none'
    packageURL: deployIOA ? entraLogSettings.ioaPackageURL : 'none'
    storageAccountName: deployIOA ? entraLogSettings.storageAccountName : 'none'
    eventHubNamespaceName: deployIOA ? eventHub.outputs.eventHubNamespaceName : 'none'
    eventHubName: deployIOA ? entraLogSettings.eventHubName : 'none'
    virtualNetworkName: deployIOA ? virtualNetwork.outputs.virtualNetworkName : 'none'
    virtualNetworkSubnetId: deployIOA ? virtualNetwork.outputs.csSubnet2Id : 'none'
    diagnosticSettingName: deployIOA ? entraLogSettings.functionAppDiagnosticSettingName : 'none'
    csCID: deployIOA ? falconCID : 'none'
    csClientIdUri: deployIOA ?  keyVault.outputs.csClientIdUri : 'none'
    csClientSecretUri:  deployIOA ? keyVault.outputs.csClientSecretUri : 'none'
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
resource activityDiagnosticSetttings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!targetManagementGroup && deployActivityLogDiagnosticSettings && deployIOA) {
  name: activityLogSettings.diagnosticSetttingsName
  properties: {
    eventHubAuthorizationRuleId: (targetManagementGroup && deployIOA && deployActivityLogDiagnosticSettings) ? eventHub.outputs.eventHubAuthorizationRuleId : 'none'
    eventHubName: (targetManagementGroup && deployIOA && deployActivityLogDiagnosticSettings) ? activityLogSettings.eventHubName : 'none'
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
module setAzureDefaultSubscription 'defaultSubscription.bicep' = if (deployIOA) {
  scope: resourceGroup(ioaRg.name)
  name: '${deploymentNamePrefix}-defaultSubscription-${deploymentNameSuffix}'
  params: {
    falconClientId: deployIOA ? falconClientId : 'none'
    falconClientSecret: deployIOA ? falconClientSecret : 'none'
    falconCloudRegion: deployIOA ? falconCloudRegion : 'US-1'
    tags: tags
  }
  dependsOn: [
    script
    certificate
    policyExemptions
  ]
}

// Deploy ACR at scal

/* Deployment outputs required for follow-up activities */
output eventHubAuthorizationRuleId string = deployIOA ? eventHub.outputs.eventHubAuthorizationRuleId : 'none'
output eventHubRuleId string = deployIOA ? eventHub.outputs.eventHubAuthorizationRuleId : 'none'
output activityLogEventHubName string = deployIOA ? eventHub.outputs.activityLogEventHubName: 'none'
output entraLogEventHubName string = deployIOA ? eventHub.outputs.entraLogEventHubName: 'none'
