param location string = resourceGroup().location
param appRegistrationId string
@secure()
param cspmCertificate string 
param userAssignedIdentityName string
param userAssignedIdentityResourceGroupName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
}

resource azureAccount 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-certificate-deployment'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '10.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
    arguments: '-appRegistrationId ${appRegistrationId} -tenantId ${tenant().tenantId} -subscriptionId ${subscription().subscriptionId} -certificate ${cspmCertificate} -userAssignedIdentityClientId ${userAssignedIdentity.properties.clientId}'
    scriptContent: '''
      param(
        [string] $appRegistrationId,
        [string] $tenantId,
        [string] $subscriptionId,
        [string] $certificate,
        [string] $userAssignedIdentityClientId
        )

      try 
      {
        Install-Module Microsoft.Graph -Force
      } 
      catch 
      {
        Write-Error "Failed to install Microsoft.Graph module: $_"
        exit 1
      }

      try 
      {
        $base64Cert = [System.Convert]::FromBase64String($certificate)
      } 
      catch 
      {
        Write-Error "Failed to convert certificate from Base64: $_"
        exit 1
      }

      try 
      {
        Connect-MgGraph -Identity -ClientId $userAssignedIdentityClientId
      } 
      catch 
      {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit 1
      }

      $KeyCredentials = @{
        DisplayName = 'CrowdStrike FCS Certificate'
        StartDateTime = (Get-Date)
        Type  = 'AsymmetricX509Cert'
        Usage = 'Verify'
        Key   = $base64Cert
      }

      try 
      {
        Update-MgApplicationByAppId -AppId $appRegistrationId -KeyCredentials $KeyCredentials
      } 
      catch 
      {
        Write-Error "Failed to update application with new key credentials: $_"
        exit 1
      }
    '''
  }
}
