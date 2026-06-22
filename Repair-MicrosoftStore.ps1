<#
.SYNOPSIS
Diagnoses and repairs Microsoft Store and App Installer registration.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Repair,
    [switch]$RepairAppInstaller,
    [string]$LogRoot="$env:ProgramData\MicrosoftStoreRepair\Logs"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$runPath=Join-Path $LogRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
$warnings=New-Object System.Collections.Generic.List[string]
$transcript=$false

function Register-Package{
    param([string]$PackageName)
    $package=Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue|Select-Object -First 1
    if(-not $package){$script:warnings.Add("Package not found: $PackageName");return}
    $manifest=Join-Path $package.InstallLocation 'AppxManifest.xml'
    if(Test-Path $manifest){Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop}
    else{$script:warnings.Add("Manifest not found: $PackageName")}
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null
    Start-Transcript -Path (Join-Path $runPath 'Transcript.txt') -Force|Out-Null
    $transcript=$true

    Get-AppxPackage -Name Microsoft.WindowsStore,Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue|
        Select-Object Name,Version,Status,InstallLocation,PackageFullName|
        Export-Csv (Join-Path $runPath 'Packages.csv') -NoTypeInformation

    Get-Service ClipSVC,AppXSvc,InstallService -ErrorAction SilentlyContinue|
        Select-Object Name,Status,StartType|
        Export-Csv (Join-Path $runPath 'Services.csv') -NoTypeInformation

    if(Get-Command winget.exe -ErrorAction SilentlyContinue){winget.exe --info 2>&1|Out-File (Join-Path $runPath 'WingetInfo.txt')}
    else{$warnings.Add('WinGet was not found.')}

    if($Repair -and $PSCmdlet.ShouldProcess('Microsoft Store cache','Run WSReset')){
        Start-Process -FilePath 'wsreset.exe' -Wait
    }

    if($Repair -and $PSCmdlet.ShouldProcess('Microsoft Store package','Re-register package')){
        Register-Package 'Microsoft.WindowsStore'
    }

    if($Repair -and $RepairAppInstaller -and $PSCmdlet.ShouldProcess('App Installer package','Re-register package')){
        Register-Package 'Microsoft.DesktopAppInstaller'
    }

    if($Repair -and (Get-Command winget.exe -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess('WinGet sources','Reset and update sources')){
        winget.exe source reset --force 2>&1|Out-File (Join-Path $runPath 'WingetSourceReset.txt')
        winget.exe source update 2>&1|Out-File (Join-Path $runPath 'WingetSourceUpdate.txt')
    }

    $warnings|Out-File (Join-Path $runPath 'Warnings.txt') -Encoding UTF8
    if($transcript){Stop-Transcript|Out-Null;$transcript=$false}
    if($warnings.Count -gt 0){Write-Host "[WARN] Completed with warnings. Logs: $runPath" -ForegroundColor Yellow;exit 2}
    Write-Host "[OK] Completed. Logs: $runPath" -ForegroundColor Green;exit 0
}catch{
    if($transcript){try{Stop-Transcript|Out-Null}catch{}}
    Write-Error $_.Exception.Message;exit 1
}
