# Install the module.
# Install-Module Microsoft.Graph -Scope CurrentUser

# The tenant ID
$TenantId = ''

# The name of your web app, which has a managed identity.
$webAppName = "" 
$resourceGroupName = ""

# The name of the app role that the managed identity should be assigned to.
$appRoleName = "Application.ReadWrite.All"

# Get the web app's managed identity's object ID.
Connect-AzAccount -Tenant $TenantId
$managedIdentityObjectId = (Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $webAppName).PrincipalId

Connect-MgGraph -TenantId $TenantId -Scopes 'Application.Read.All','AppRoleAssignment.ReadWrite.All','Directory.ReadWrite.All'

# Get Microsoft Graph app's service principal and app role.
$serverApplicationName = "Microsoft Graph"
$serverServicePrincipal = (Get-MgServicePrincipal -Filter "DisplayName eq '$serverApplicationName'")
$serverServicePrincipalObjectId = $serverServicePrincipal.Id

$appRoleId = ($serverServicePrincipal.AppRoles | Where-Object {$_.Value -eq $appRoleName }).Id

# Assign the managed identity access to the app role.
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $managedIdentityObjectId `
    -PrincipalId $managedIdentityObjectId `
    -ResourceId $serverServicePrincipalObjectId `
    -AppRoleId $appRoleId

