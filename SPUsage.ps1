param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $configLocation
)

[xml]$configXml = Get-Content $configLocation

Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue
## Service Application Names
$usageSAName = $configXml.Configuration.UsageSAName

## Settings Specific to Usage Service
$appServerName1 = $configXml.Configuration.AppServerName1
$appServerName2 = $configXml.Configuration.AppServerName2
$saAppPoolName = $configXml.Configuration.ServiceApplicationAppPoolName
$AppPoolAcct = $configXml.Configuration.AppPoolAcct
$databaseServerName = $configXml.Configuration.DatabaseServerName
$usageDatabaseName = $configXml.Configuration.UsageDatabaseName
$usageLogLocation = $configXml.Configuration.UsageLogLocation
$usageLogSize = $configXml.Configuration.UsageLogMaxFileSizeKB

## Create Usage Service Application Pools
$saAppPool = Get-SPServiceApplicationPool -Identity $saAppPoolName -EA 0
if($saAppPool -eq $null)
{
  Write-Host "Creating Usage Service Application Pool..."
 
  ## Managed Account
    $ManagedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq $AppPoolAcct}
    If ($ManagedAccountGen -eq $NULL) { throw " - Managed Account $AppPoolAcct not found" }      
    ## App Pool
	Write-Host -ForegroundColor White " - Getting Hosted Services Application Pool, creating if necessary..."
    $saAppPool = Get-SPServiceApplicationPool $saAppPoolName -ea SilentlyContinue
    If ($saAppPool -eq $null)
	{ 
        $saAppPool = New-SPServiceApplicationPool $saAppPoolName -account $ManagedAccountGen 
        If (-not $?) { throw " - Failed to create the application pool" }
    }
}
## This section creates Usage service
Write-Host "Creating Usage Service and Proxy..."

#$serviceInstance = Get-SPUsageService
New-SPUsageApplication -Name $usageSAName -DatabaseServer $databaseServerName -DatabaseName $usageDatabaseName

Get-SPServiceInstance -server $appServerName1 | where-object {$_.TypeName -eq $usageSAName} | Start-SPServiceInstance > $null
Get-SPServiceInstance -server $appServerName2 | where-object {$_.TypeName -eq $usageSAName} | Start-SPServiceInstance > $null
$usageProxy = Get-SPServiceApplicationProxy| where-object {$_.Name -eq "$usageSAName"}
$usageProxy.provision() 

Write-Host "Setting usage log service..."

Set-SPUsageService -UsageLogLocation $UsageLogLocation -UsageLogMaxFileSizeKB $usageLogSize

Write-Host "Press any key to continue ..."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")