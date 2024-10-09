$clientID = ''
$clientSecret = ''
$tenantId = ''
$subscriptionId = ''
# Get access token
$response = Invoke-RestMethod -Uri "https://api.crowdstrike.com/oauth2/token" -Method POST -Headers @{
    "Accept"       = "application/json"
    "Content-Type" = "application/x-www-form-urlencoded"
} -Body "client_id=$ClientID&client_secret=$ClientSecret"

$accessToken = $response.access_token

# Prepare subscription JSON
$subjson = @{
    "resources" = @(
        @{
            "account_type" = "string"
            "client_id" = ""
            "default_subscription" = $true
            "subscription_id" = $subscriptionId
            "tenant_id" = $tenantId
            "years_valid" = 10
        }
    )
}

# Create CSPM account
Invoke-RestMethod -Method POST -Uri "https://api.crowdstrike.com/cloud-connect-cspm-azure/entities/account/v1" -Headers @{
    Authorization = "Bearer $accessToken"
} -ContentType 'application/json' -Body (ConvertTo-Json $subjson) -Debug
