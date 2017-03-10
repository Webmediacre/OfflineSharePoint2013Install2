param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $installPath, 
    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    $offline
)

# Global variables
$Global:RegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$Global:powershell = (Join-Path $env:windir "system32\WindowsPowerShell\v1.0\powershell.exe")
$Global:restartKey = "SPInstaller-Restart"
$Global:silentConfig = "SilentConfig.xml"
$Global:ScriptLocal = $MyInvocation.MyCommand.Path

$Global:HasRestarted = $false

# Installs sharepoint prerequisies
function InstallPrerequisites{
    Write-Host "Installing Prerequisites..." -ForegroundColor Yellow

    $path = Join-Path $installPath prerequisiteinstaller.exe
    $process = $null

    if($offline -eq 'y')
    {
        if($Global:HasRestarted)
        {
            $process = (Start-Process -Wait -PassThru $path /continue)
        }
        else{
            $process = (Start-Process -Wait -PassThru $path)
        }
        
    }
    else{
        $arguments = "/unattended"

        if($Global:HasRestarted)
        {
            $arguments = $arguments + " /continue"
        }

        $process = (Start-Process -Wait -PassThru $path $arguments)
    }

    CheckPrerequisites($process.ExitCode)
}

# Displays messages and restarts if needed
function CheckPrerequisites($exitCode){
    switch ($exitCode)
    {
        0 {
            Write-Host "Prerequisites installed successfully" -ForegroundColor Green 
        }
        1001 {
            Write-Host "Restart is needed" -ForegroundColor Yellow
            Restart
        }
        3010 {
            Write-Host "Restart is needed" -ForegroundColor Yellow
            Restart
        }
        default {
            Write-Host "Installation has failed" -ForegroundColor Red
        }
    }
    return $exitCode
}

# Installs SharePoint Binaries
function InstallSharepoint{
    Write-Host "Installing SharePoint..." -ForegroundColor Green

    $args = "/config " + $Global:silentConfig
    $path = Join-Path $installPath "Setup.exe"
    $sharepoint = (Start-Process -Wait -PassThru $path -ArgumentList $args)

    switch($sharepoint.ExitCode)
    {
        0 {
            Write-Host "SharePoint successfully installed" -ForegroundColor Green
        }
        default{
            Write-Host "An error has occured. Code: " $sharepoint.ExitCode -ForegroundColor Red
        }
    }

    return $sharepoint.ExitCode
}

# Restarts the machine with the script as a startup task
function Restart{
    $restartScript = (Join-Path (Split-Path -parent $Global:ScriptLocal) SPInstallerRestart.ps1)
    
    $scriptArgs = $Global:ScriptLocal + " $installPath $offline"

    $valueArgs = "$global:powershell (" + $restartScript + " " + $scriptArgs + ")"

    Set-ItemProperty -path $Global:RegKey -name $global:restartKey -value $valueArgs
    Restart-Computer
}

# Checks if a restart has occured and removes script from startup
function CheckRestart{
    if((Test-Path $Global:RegKey) -and (((Get-ItemProperty $Global:RegKey).$Global:restartKey) -ne $null))
    {
        $Global:HasRestarted = $true
        Remove-ItemProperty -path $Global:RegKey -name $Global:restartKey
    }
}

# Creates prompt for user to press key
function Wait-KeyPress {	
    Read-Host -Prompt "Press any key to continue..."
}

# Checks if resources needed for script are avaliable
function RunChecks{
    $valid = 1
    
    # Path to SP install files
    if(!(Test-Path $installPath))
    {
        InvalidPath($installPath)
        $valid = 0
    } 

    # PrerequisiteInstaller.exe
    $preReqFile = Join-Path $installPath prerequisiteinstaller.exe
    if(!(Test-Path $preReqFile))
    {
        InvalidPath($preReqFile)
        $valid = 0
    } 

    #Setup.exe
    $setupFile = Join-Path $installPath setup.exe
    if(!(Test-Path $setupFile))
    {
        InvalidPath($setupFile)
        $valid = 0
    } 

    #Silent config file for this script config
    $Global:silentConfig = Join-Path (Split-Path -parent $Global:ScriptLocal) SilentConfig.xml
    if(!(Test-Path $Global:silentConfig))
    {
        InvalidPath($Global:silentConfig)
        $valid = 0
    } 

    return $valid
}

# Prints error message on path not found
function InvalidPath($path)
{
    Write-Host "Path '" + $path + "' was not found" -ForegroundColor Red
}

# Check if restart has occured
CheckRestart

# Check resources are avaliable
if((RunChecks) -eq 1)
{
    # Check/Install prerequisites
    if((InstallPrerequisites) -eq 0)
    {
        # Install SharePoint
        if((InstallSharepoint) -eq 0)
        {
            Write-Host "SharePoint sucessfully installed" -ForegroundColor Green

        } else {
            Write-Host "SharePoint install failed" -ForegroundColor Red
        }
    }
} 

Wait-KeyPress