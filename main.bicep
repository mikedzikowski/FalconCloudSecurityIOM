targetScope = 'tenant'

param targetManagementGroup bool = true

param managementGroupId string 

param defaultSubscriptionId string 

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The suffix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-ioa'

@description('The client ID for the Falcon API.')
param falconClientId string 

@description('The client secret for the Falcon API.')
@secure()
param falconClientSecret string 

@description('The CID for the Falcon API.')
param falconCID string

@description('The app registration ID for the Azure AD application.')
param appRegistrationAppId string 

param appRegistrationObjectId string

@description('The name of the user-assigned managed identity.')
param uamiName string 

@description('The resource Id of the user-assigned managed identity.')
param uamiResourceId string

param deployIOA bool = true
param deployIOM bool = true


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

var location =  deployment().location

resource managementGroup 'Microsoft.Management/managementGroups@2023-04-01' = if (targetManagementGroup) {
  name: targetManagementGroup ? managementGroupId : 'none'
}

// Create Azure Account in CrowdStrike
module fcsManagementGroup './modules/fcs-deploy-managementgroup.bicep' = if (deployIOM && targetManagementGroup) {
  scope: subscription(defaultSubscriptionId)
  name: 'cs-deploy-mg-${deploymentNameSuffix}'
  params: {
    falconClientId: deployIOM && targetManagementGroup ? falconClientId : 'none'
    falconClientSecret: deployIOM && targetManagementGroup ? falconClientSecret : 'none'
    defaultSubscriptionId: deployIOM && targetManagementGroup ? defaultSubscriptionId : 'none'
    deployIOM: deployIOM
    targetManagementGroup: targetManagementGroup
  }
  dependsOn: [
   
  ]
}

module cspmTargetSubscription './modules/fcs-deploy-subscription.bicep' =  {
  scope: subscription(defaultSubscriptionId)
  name: 'cs-deploy-subscription-${deploymentNameSuffix}'
  params: {
    appRegistrationAppId: appRegistrationAppId
    falconCID: falconCID
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    falconCloudRegion: falconCloudRegion
    uamiName: uamiName
    uamiResourceId: uamiResourceId
    deployIOA: deployIOA
    deployIOM: deployIOM
    deployActivityLogDiagnosticSettings: deployActivityLogDiagnosticSettings
    deployEntraLogDiagnosticSettings: deployEntraLogDiagnosticSettings
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    targetManagementGroup: targetManagementGroup
  }
  dependsOn: [
    managementGroup
    fcsManagementGroup
  ]
}

// Deploy policy and role assignment at the management group level
module configureAzureManagementGroup './modules/configureAzureManagementGroup.bicep' = if (targetManagementGroup) {
  name: 'cs-configure-azure-mg-${deploymentNameSuffix}'
  scope:  managementGroup
  params: {
    principalId: targetManagementGroup ? appRegistrationObjectId : 'none'
    eventHubName: targetManagementGroup ? cspmTargetSubscription.outputs.activityLogEventHubName : 'none'
    eventHubRuleId: targetManagementGroup ? cspmTargetSubscription.outputs.eventHubAuthorizationRuleId : 'none'
    managementGroupName: targetManagementGroup ? managementGroup.name : 'none'
    location: targetManagementGroup ? location : 'none'
  }
  dependsOn: [
    cspmTargetSubscription
    fcsManagementGroup
  ]
}
