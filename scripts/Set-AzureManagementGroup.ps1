$clientID = ''
$clientSecret = ''
$tenantId = ''
$subscriptionId = ''

$RestMethodParams = @{
    URI     = "https://api.crowdstrike.com" + "/oauth2/token"
    Method  = "POST"
    Headers = @{
        "Accept"       = "application/json"
        "Content-Type" = "application/x-www-form-urlencoded"
    }
    Body    = "client_id=$ClientID&client_secret=$ClientSecret"
}
$response = Invoke-RestMethod @RestMethodParams

$accessToken = $response.access_token

$json = @{
    resources = @(
        @{
            "default_subscription_id" = $subscriptionId
            "tenant_id"= $tenantId
            "client_id" = ""
        }
    )
}


$headers = @{
    Authorization="Bearer $accessToken"
}

Invoke-RestMethod -Method POST -Uri "https://api.crowdstrike.com/cloud-connect-cspm-azure/entities/management-group/v1" -Headers $Headers -ContentType 'application/json' -Body (ConvertTo-Json $json)
