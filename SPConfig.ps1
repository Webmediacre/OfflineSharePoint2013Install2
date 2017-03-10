param(  
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $configLocation, 
    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $createJoin,

    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $isCA
)

$Global:ScriptLocal = $MyInvocation.MyCommand.Path
#$Global:Port = 9999

# Creates prompt for user to press key
function Wait-KeyPress {	
    Read-Host -Prompt "Press any key to continue..."
}

# Checks if resources needed for script are avaliable
function RunChecks{
    $valid = 1

    #Farm config file
    if(!(Test-Path $configLocation))
    {
        InvalidPath($configLocation)
        $valid = 0
    } 
    return $valid
}

# Prints error message on path not found
function InvalidPath($path)
{
    Write-Host "Path '" + $path + "' was not found" -ForegroundColor Red
}

# Creates/Joins new SP farm
function Create_JoinFarmDatabases{
    Write-Host "Creating farm config & admin databases..." -ForegroundColor Green

    [xml]$configXml = Get-Content $configLocation

    # SQL Server variable 
    $SQLServer = $configXml.Configuration.SQLServer
    $SQLUsername = $configXml.Configuration.SQLUsername
    $SQLPassword = $configXml.Configuration.SQLPassword
    $FarmPassphrase = $configXml.Configuration.PassPhrase
    $ConfigDB = $configXml.Configuration.ConfigDB
    $AdminDB = $configXml.Configuration.AdminDB
    $Global:Port = $configXml.Configuration.Port

    $FarmCredentials = New-Object System.Management.Automation.PSCredential $SQLUsername, (ConvertTo-SecureString $SQLPassword -AsPlainText -Force)
    #$FarmPassphrase = Read-Host "Enter passphrase" -AsSecureString 

    if($createJoin -eq "create")
    {
        Write-Host " - Creating databases..." -ForegroundColor Green
        New-SPConfigurationDatabase -DatabaseServer $SQLServer -DatabaseName $ConfigDB -AdministrationContentDatabaseName $AdminDB -Passphrase (ConvertTo-SecureString $FarmPassphrase -AsPlainText -Force) -FarmCredentials $FarmCredentials
    
        if (-not $?) { 
            throw "Configuration database could not be setup"    
        }

        Write-Host "Databases created. Config: " + $ConfigDB + " Admin: " + $AdminDB -ForegroundColor Green
    }
    else{
        Write-Host " - Joining databases..." -ForegroundColor Green
        Connect-SPConfigurationDatabase -DatabaseServer $SQLServer -DatabaseName $ConfigDB -Passphrase (ConvertTo-SecureString $FarmPassphrase -AsPlainText -Force)

        if (-not $?) { 
            throw "Configuration database could not be joined"    
        }

        Write-Host "Databases joined. Config: " + $ConfigDB + " Admin: " + $AdminDB -ForegroundColor Green
    }
}

function InstallSPFeatures{
    Write-Host "Installing SP features..." -ForegroundColor Green

    Install-SPHelpCollection -All
    Initialize-SPResourceSecurity
    Install-SPService  
    Install-SPFeature -AllExistingFeatures 

    if($isCA -eq "y")
    {
        New-SPCentralAdministration -Port $Global:Port -WindowsAuthProvider NTLM 
    }

    Install-SPApplicationContent

    Write-Host "SP features installed" -ForegroundColor Green
}

# Check resources are avaliable
if((RunChecks) -eq 1)
{
    try{
        Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
        if(Get-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue)
        {
            Create_JoinFarmDatabases
            InstallSPFeatures

            Remove-PSSnapin Microsoft.SharePoint.PowerShell

            Write-host "Success" -ForegroundColor Green
        }
        else{
            Write-host "SharePoint not found" -ForegroundColor Red
        }
    } catch{
        Write-host "Error creating/joining farm" -ForegroundColor Red
    } 
}


Wait-KeyPress