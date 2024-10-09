#Requires -Version 5.1
using module @{ModuleName='PSFalcon';ModuleVersion='2.2'}
[CmdletBinding()]
param(
    [Parameter(Mandatory,Position=1)]
    [ValidatePattern('^[a-fA-F0-9]{32}$')]
    [string]$ClientId,
    [Parameter(Mandatory,Position=2)]
    [ValidatePattern('^\w{40}$')]
    [string]$ClientSecret,
    [Parameter(Position=3)]
    [ValidatePattern('^[a-fA-F0-9]{32}$')]
    [string]$MemberCid,
    [Parameter(Position=4)]
    [ValidateSet('us-1','us-2','us-gov-1','eu-1')]
    [string]$Cloud
)
begin {
    $Token = @{}
    @('ClientId','ClientSecret','Cloud','MemberCid').foreach{
        if ($PSBoundParameters.$_) { $Token[$_] = $PSBoundParameters.$_ }
    }
}
process {
    try {
        Request-FalconToken @Token
        if ((Test-FalconToken).Token -eq $true) {
            $newAccount = New-FalconHorizonAzureAccount -SubscriptionId $subscriptionID -TenantId $tenantId -ClientId $clientID 
            $cert = (Get-FalconHorizonAzureCertificate -TenantId $tenantId).public_certificate
            # $secureCert = ConvertTo-SecureString -String $cert -AsPlainText -Force
            # Set-AzKeyVaultSecret  -VaultName 'test-cspm-cs' -SecretValue $secureCert -Name "crowdstrike-cspm-cert"     
        }
    } catch {
        throw $_
    } finally {
        if ((Test-FalconToken).Token -eq $true) { Revoke-FalconToken }
    }
}