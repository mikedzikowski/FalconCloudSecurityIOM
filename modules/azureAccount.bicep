param location string = resourceGroup().location

param falconClientId string
@secure()
param falconClientSecret string
param appRegistration string

resource azureAccount 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-account-deployment'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '10.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    arguments: '-clientId ${falconClientId} -clientSecret ${falconClientSecret} -appRegistrationId ${appRegistration} -tenantId ${tenant().tenantId} -subscriptionId ${subscription().subscriptionId}'
    scriptContent: '''
      param(
        [string] $clientId,
        [string] $clientSecret,
        [string] $appRegistrationId,
        [string] $tenantId,
        [string] $subscriptionId
    )
    $ErrorActionPreference = 'Stop'
    # Authenticate to Falcon Cloud Security
    Install-Module -Name PSFalcon -Force 

    # Build token request
    $Token = @{
        ClientId     = $clientId
        ClientSecret = $clientSecret
    }

    # Request token
    Request-FalconToken @Token

    # Create Azure Account in Falcon Horizon
    New-FalconHorizonAzureAccount -subscriptionId $subscriptionId -TenantId $tenantId -ClientId $appRegistrationId 

    # Get certificate
    $cert = (Get-FalconHorizonAzureCertificate -TenantId $tenantId).public_certificate

    # Output certificate
    $DeploymentScriptOutputs['text'] = $cert

    Write-Output $cert
    '''
  }
}

output text string = azureAccount.properties.outputs['text']
