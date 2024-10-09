
param keyVaultName string
param resourceGroupName string
param deploymentNameSuffix string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

module appCertificate './appRegistrationCertificate.bicep' = {
  scope: resourceGroup(resourceGroupName)
  name: 'appcert-deployment-${deploymentNameSuffix}'
  params: {
    appName: 'crowdstrike'
    deployEnvironment: 'cspm'
    cspmCertificate: keyVault.getSecret('falcon-cspm-certificate')
  }
  dependsOn: [
    keyVault
  ]
}
