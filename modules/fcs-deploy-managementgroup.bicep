targetScope = 'subscription'

@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()
@description('The name of the resource group.')
param iomResourceGroupName string = 'cs-iom-group'
param deployIOM bool 
param targetManagementGroup bool
param falconClientId string
@secure()
param falconClientSecret string
param defaultSubscriptionId string

resource iomRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: iomResourceGroupName
  location: location
}

// Create fcs managenent group in CrowdStrike Falcon Horizon
module fcsMg './fcs-onboard-azure-managementgroup.bicep' = if (deployIOM && targetManagementGroup) {
  scope: resourceGroup(iomRg.name)
  name: 'cs-fcs-mg-deployment-${deploymentNameSuffix}'
  params: {
    falconClientId: deployIOM && targetManagementGroup ? falconClientId : 'none'
    falconClientSecret: deployIOM && targetManagementGroup ? falconClientSecret : 'none'
    defaultSubscriptionId: deployIOM && targetManagementGroup ? defaultSubscriptionId : 'none'
  }
  dependsOn: [

  ]
}
