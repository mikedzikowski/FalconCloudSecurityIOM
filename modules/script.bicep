param location string
param appName string
param certificatePath string
param userIdentityId string
param userIdentityClientId string

resource createAppAndUploadCert 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'createAppAndUploadCert'
  kind: 'AzureCLI'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityId}': {}
    }
  }
  properties: {
    retentionInterval: 'P1D'
    forceUpdateTag: '1.0'
    azCliVersion: '2.45.0'  // Specify the required Azure CLI version
    scriptContent: '''
      # Log in using the managed identity
      az login --identity --username ${userAssignedIdentityClientId}

      # Create the app registration
      appId=$(az ad app create --display-name ${appName} --query "appId" -o tsv)

      # Upload the certificate
      #az ad app credential reset --id $appId --cert @${certificatePath} --append
    '''
    cleanupPreference: 'Always'
    environmentVariables: [
      {
        name: 'userAssignedIdentityClientId'
        value: userIdentityClientId
      }
      {
        name: 'appName'
        value: appName
      }
      {
        name: 'certificatePath'
        value: certificatePath
      }
    ]
  }
}
