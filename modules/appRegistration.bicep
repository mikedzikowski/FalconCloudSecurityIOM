
targetScope = 'subscription'

// entra-external-setup.bicep
extension microsoftGraph

param appName string = 'crowdstrike'
param deployEnvironment string = 'cspm'

var applicationRegistrationName = '${appName}-${deployEnvironment}-app'
var redirectUris = ['https://localhost']

resource microsoftGraphServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: '00000003-0000-0000-c000-000000000000'
}

resource applicationRegistration 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: applicationRegistrationName
  displayName: applicationRegistrationName
  web: {
    redirectUris: [for item in redirectUris: '${item}/sigin-oidc']
    implicitGrantSettings: {
      enableIdTokenIssuance: true
    }
  }
  requiredResourceAccess: [
    {
      resourceAppId: microsoftGraphServicePrincipal.appId
      resourceAccess: [
        {id: 'df021288-bdef-4463-88db-98f22de89214', type: 'Role'} // User.Read.All
        {id: 'aec28ec7-4d02-4e8c-b864-50163aea77eb', type: 'Scope'} // UserAuthenticationMethod.Read.All
        {id: '49f0cc30-024c-4dfd-ab3e-82e137ee5431', type: 'Scope'} // DeviceManagementRBAC.Read.All
        {id: '230c1aed-a721-4c5d-9cb4-a90514e508ef', type: 'Role'} // Reports.Read.All
        {id: '246dd0d5-5bd0-4def-940b-0421030a5b68', type: 'Role'} // Policy.Read.All
        {id: '483bed4a-2ad3-4361-a73b-c83ccdbdc53c', type: 'Role'} // RoleManagement.Read.Directory
        {id: '5b567255-7703-4780-807c-7be8301ae99b', type: 'Role'} // Group.Read.All
        {id: '7ab1d382-f21e-4acd-a863-ba3e13f7da61', type: 'Role'} // Directory.Read.All
        {id: '9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30', type: 'Role'} // Application.Read.All
        {id: 'b0afded3-3588-46d8-8b3d-9842eff778da', type: 'Role'} // AuditLog.Read.All
        {id: '97235f07-e226-4f63-ace3-39588e11d3a1', type: 'Role'} // User.ReadBasic.All
      ]
    }
  ]
}

resource applicationRegistrationServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: applicationRegistration.appId
}

resource delegatedGrants 'Microsoft.Graph/oauth2PermissionGrants@v1.0' = {
  clientId: applicationRegistrationServicePrincipal.id
  consentType: 'AllPrincipals'
  resourceId: microsoftGraphServicePrincipal.id
  scope: 'UserAuthenticationMethod.Read.All DeviceManagementRBAC.Read.All'
}

resource userReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: 'df021288-bdef-4463-88db-98f22de89214'
}

resource reportsReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '230c1aed-a721-4c5d-9cb4-a90514e508ef'
}

resource policyReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '246dd0d5-5bd0-4def-940b-0421030a5b68'
}

resource roleManagementReadDirectory 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '483bed4a-2ad3-4361-a73b-c83ccdbdc53c'
}

resource groupReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '5b567255-7703-4780-807c-7be8301ae99b'
}

resource directoryReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
}

resource applicationReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30'
}

resource auditLogReadAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: 'b0afded3-3588-46d8-8b3d-9842eff778da'
}

resource userReadBasicAll 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  principalId: applicationRegistrationServicePrincipal.id
  resourceId: microsoftGraphServicePrincipal.id
  appRoleId: '97235f07-e226-4f63-ace3-39588e11d3a1'
}

output applicationRegistrationId string = applicationRegistration.id
output principalId string = applicationRegistrationServicePrincipal.appId
output appId string = applicationRegistration.appId
