param location string = resourceGroup().location
param falconClientId string
@secure()
param falconClientSecret string
param defaultSubscriptionId string

var tenantId = subscription().tenantId

resource azureAccount 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-mg-deployment'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '10.0'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
    arguments: '-clientId ${falconClientId} -clientSecret ${falconClientSecret} -tenantId ${tenantId} -defaultSubscriptionId ${defaultSubscriptionId}'
    scriptContent: '''
      param(
        [string] $clientId,
        [string] $clientSecret,
        [string] $tenantId,
        [string] $defaultSubscriptionId
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
      # Create FCS Azure Management Group in Falcon Horizon 
      # NEED TO UPDATE TEST 
      $test =  $null
      if ($test -ne $null) 
      {
        Write-Output "Management Group already exists in Falcon Horizon"
      }
      else 
      {
        New-FalconCloudAzureGroup -DefaultSubscriptionId $defaultSubscriptionId -TenantId $tenantId 
      }
   }
    catch 
    {
      Write-Error "Failed to create FCS MG in Falcon Horizon: $_"
      throw
    }
    '''
  }
}
