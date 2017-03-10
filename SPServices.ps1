param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $configLocation
)

[xml]$configXml = Get-Content $configLocation
Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

####################### Start Services ################################

## Settings you may want to change ##
$databaseServerName = $configXml.Configuration.DatabaseServerName
#$searchServerName = ""
$WebServerName1 = $configXml.Configuration.WebServerName1
$WebServerName2 = $configXml.Configuration.WebServerName2
$appServerName1 = $configXml.Configuration.AppServerName1
$appServerName2 = $configXml.Configuration.AppServerName2
$saAppPoolName = $configXml.Configuration.ServiceApplicationAppPoolName
$ssAppPoolName = $configXml.Configuration.SecureStoreAppPoolName
$AppPoolAcct = $configXml.Configuration.AppPoolAcct
$SSAppPoolAcct = $configXml.Configuration.SecureStoreAppPoolAcct
 
## Service Application Service Names ##
$excelSAName = $configXml.Configuration.ExcelSAName
$metadataSAName = $configXml.Configuration.MetaDataSAName
$secureStoreSAName = $configXml.Configuration.SecureStoreSAName

$MetaDataDatabaseName = $configXml.Configuration.MetaDataDatabaseName
$SecureStoreDatabaseName = $configXml.Configuration.SecureStoreDatabaseName


$saAppPool = Get-SPServiceApplicationPool -Identity $saAppPoolName -EA 0
if($saAppPool -eq $null)
{
  Write-Host "Creating Generic Service Application Pool..."
 
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

$ssAppPool = Get-SPServiceApplicationPool -Identity $ssAppPoolName -EA 0
if($ssAppPool -eq $null)
{
  Write-Host "Creating Secure Store Service Application Pool..."
 
  ## Managed Account
      	$ManagedAccountGen = Get-SPManagedAccount | Where-Object {$_.UserName -eq $SSAppPoolAcct}
      	If ($ManagedAccountGen -eq $NULL) { throw " - Managed Account $SSAppPoolAcct not found" }      
      	## App Pool
	  	Write-Host -ForegroundColor White " - Getting Hosted Services Application Pool, creating if necessary..."
      	$ssAppPool = Get-SPServiceApplicationPool $ssAppPoolName -ea SilentlyContinue
      	If ($ssAppPool -eq $null)
	  	{ 
            $ssAppPool = New-SPServiceApplicationPool $ssAppPoolName -account $ManagedAccountGen 
            If (-not $?) { throw " - Failed to create the application pool" }
      	}
}
   
Get-SPServiceApplicationPool 

Write-Host "Creating Excel Service..."
New-SPExcelServiceApplication -name $excelSAName –ApplicationPool $saAppPoolName > $null -erroraction SilentlyContinue
Set-SPExcelFileLocation -Identity "http://" -ExcelServiceApplication $excelSAName -ExternalDataAllowed 2 -WorkbookSizeMax 10 -WarnOnDataRefresh:$true
Get-SPServiceInstance -server $appServerName1 | where-object {$_.TypeName -eq "Excel Calculation Services"} | Start-SPServiceInstance > $null
Get-SPServiceInstance -server $appServerName2 | where-object {$_.TypeName -eq "Excel Calculation Services"} | Start-SPServiceInstance > $null
Get-SPServiceApplication

Write-Host "Creating Metadata Service and Proxy..."
New-SPMetadataServiceApplication -Name $metadataSAName -ApplicationPool $saAppPoolName -DatabaseServer $databaseServerName -DatabaseName $MetaDataDatabaseName > $null -erroraction SilentlyContinue
New-SPMetadataServiceApplicationProxy -Name "$metadataSAName Proxy" -DefaultProxyGroup -ServiceApplication $metadataSAName > $null -erroraction SilentlyContinue
Get-SPServiceInstance -server $WebServerName1 | where-object {$_.TypeName -eq "Managed Metadata Web Service"} | Start-SPServiceInstance > $null
Get-SPServiceInstance -server $WebServerName1 | where-object {$_.TypeName -eq "Managed Metadata Web Service"} | Start-SPServiceInstance > $null
Get-SPServiceApplication

Write-Host "Creating Secure Store Service and Proxy..."
New-SPSecureStoreServiceApplication –Name $secureStoreSAName –ApplicationPool $ssAppPoolName –AuditingEnabled:$true –DatabaseServer $databaseServerName –DatabaseName $SecureStoreDatabaseName > $null -erroraction SilentlyContinue
$ssapp = Get-SPServiceApplication | where-object {$_.Name -eq $secureStoreSAName}
New-SPSecureStoreServiceApplicationProxy –Name "$secureStoreSAName Proxy" -DefaultProxyGroup –ServiceApplication $ssapp > $null -erroraction SilentlyContinue
Get-SPServiceInstance -server $appServerName1 | where-object {$_.TypeName -eq "Secure Store Service"} | Start-SPServiceInstance > $null
Get-SPServiceInstance -server $appServerName2 | where-object {$_.TypeName -eq "Secure Store Service"} | Start-SPServiceInstance > $null
Get-SPServiceApplication
 

########################### Stop Services ###################################
$CacheServerName1 = $configXml.Configuration.CacheServerName1
$CacheServerName2 = $configXml.Configuration.CacheServerName2

$SrchServerName1 = $configXml.Configuration.SrchServerName1
$SrchServerName2 = $configXml.Configuration.SrchServerName2
$SrchServerName3 = $configXml.Configuration.SrchServerName3
$SrchServerName4 = $configXml.Configuration.SrchServerName4


#Stop Services on Web Servers 
Get-SPServiceInstance -server $WebServerName1 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false

Get-SPServiceInstance -server $WebServerName2 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false

#Stop Services on Distributed Cache Servers
Get-SPServiceInstance -server $CacheServerName1 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false

Get-SPServiceInstance -server $CacheServerName2 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false

#Stop Services on Application Servers
Get-SPServiceInstance -server $AppServerName1 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false
Get-SPServiceInstance -server $AppServerName1 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"} | Stop-SPServiceInstance > $null -Confirm:$false

Get-SPServiceInstance -server $AppServerName2 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false
Get-SPServiceInstance -server $AppServerName2 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"} | Stop-SPServiceInstance > $null -Confirm:$false

#Stop Services on Search Servers
Get-SPServiceInstance -server $SrchServerName1 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false
Get-SPServiceInstance -server $SrchServerName1 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"} | Stop-SPServiceInstance > $null -Confirm:$false

Get-SPServiceInstance -server $SrchServerName2 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false
Get-SPServiceInstance -server $SrchServerName2 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"} | Stop-SPServiceInstance > $null -Confirm:$false

Get-SPServiceInstance -server $SrchServerName3 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false
Get-SPServiceInstance -server $SrchServerName3 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"} | Stop-SPServiceInstance > $null -Confirm:$false

Get-SPServiceInstance -server $SrchServerName4 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Incoming E-Mail"} | Stop-SPServiceInstance > $null -Confirm:$false
Get-SPServiceInstance -server $SrchServerName4 | where-object {$_.TypeName -eq "Microsoft SharePoint Foundation Web Application"} | Stop-SPServiceInstance > $null -Confirm:$false

Write-Host "Press any key to continue ..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")