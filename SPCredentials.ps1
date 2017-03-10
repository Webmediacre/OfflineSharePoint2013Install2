param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $configLocation
)

Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

[xml]$configXml = Get-Content $configLocation

$credentials = $configXml.Credentials.Account

foreach($credential in $credentials)
{
    $Credential = New-Object System.Management.Automation.PSCredential $credential.User, (ConvertTo-SecureString $credential.Password -AsPlainText -Force)
    New-SPManagedAccount $Credential
}