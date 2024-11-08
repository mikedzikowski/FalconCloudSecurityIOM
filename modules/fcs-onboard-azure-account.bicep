param location string = resourceGroup().location
param falconClientId string
@secure()
param falconClientSecret string
param appRegistration string
param subscriptionId string

var tenantId = subscription().tenantId

resource azureAccount 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-account-deployment'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '10.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
    arguments: '-clientId ${falconClientId} -clientSecret ${falconClientSecret} -appRegistrationId ${appRegistration} -tenantId ${tenantId} -subscriptionId ${subscriptionId}'
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
    try 
    {
      Install-Module -Name PSFalcon -Force
    } 
    catch
    {
      Write-Error "Failed to install PSFalcon module: $_"
      throw
    }

    try
    {
      # Build token request
      $Token = @{
        ClientId     = $clientId
        ClientSecret = $clientSecret
      }
      # Request token
      Request-FalconToken @Token
    } 
    catch 
     {
      Write-Error "Failed to request Falcon token: $_"
      throw
    }

    try 
    {
      # Create Azure Account in Falcon Horizon
      $test =  $null
      if ($test -ne $null) 
      {
        Write-Output "Azure account already exists in Falcon Horizon"
      }
      else 
      {
        New-FalconHorizonAzureAccount -subscriptionId $subscriptionId -TenantId $tenantId -ClientId $appRegistrationId
      }
   }
    catch 
    {
      Write-Error "Failed to create Azure account in Falcon Horizon: $_"
      throw
    }

    try 
    {
      # Get certificate
      $cert = (Get-FalconHorizonAzureCertificate -TenantId $tenantId).public_certificate

      # Output certificate
      $DeploymentScriptOutputs['text'] = $cert
      Write-Output $cert
    } 
    catch 
    {
      Write-Error "Failed to get or output certificate: $_"
      throw
    }
    '''
  }
}

output text string = azureAccount.properties.outputs['text']
