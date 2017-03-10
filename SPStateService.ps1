param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $configLocation
)

[xml]$configXml = Get-Content $configLocation

Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

$stateServiceName = $configXml.Configuration.StateServiceName
$stateServiceDBName = $configXml.Configuration.StateServiceDBName

$stateServiceDB = New-SPStateServiceDatabase -Name $stateServiceDBName
$stateService = New-SPStateServiceApplication -Name $stateServiceName -Database $stateServiceDB
New-SPStateServiceApplicationProxy -Name ”$stateServiceName Proxy” -ServiceApplication $stateService –DefaultProxyGroup



