
targetScope = 'resourceGroup'
// entra-external-setup.bicep
extension microsoftGraph

param appName string = 'crowdstrike'
param deployEnvironment string = 'cspm'
@secure()
param cspmCertificate string

var applicationRegistrationName = '${appName}-${deployEnvironment}-app'

resource applicationRegistration 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: applicationRegistrationName
  displayName: applicationRegistrationName
  keyCredentials: [
    {
      type: 'AsymmetricX509Cert'
      usage: 'Verify'
      key: cspmCertificate
      displayName: 'CrowdStrike'
    }
  ]
}
