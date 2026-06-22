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

function Test-Admin{
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-TargetPackage{
    param([string]$PackageName)
    $package=Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue|Select-Object -First 1
    if(-not $package -and (Test-Admin)){
        $package=Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue|Select-Object -First 1
    }
    $package
}

function Register-Package{
    param([string]$PackageName)
    $package=Get-TargetPackage $PackageName
    if(-not $package){$script:warnings.Add("Package not found: $PackageName");return}
    $manifest=Join-Path $package.InstallLocation 'AppxManifest.xml'
    if(-not(Test-Path $manifest)){$script:warnings.Add("Manifest not found: $PackageName");return}
    Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
}

function Invoke-WingetSource{
    param([string]$Name,[string[]]$Arguments)
    winget.exe @Arguments 2>&1|Out-File (Join-Path $runPath ($Name+'.txt'))
    if($LASTEXITCODE -ne 0){$script:warnings.Add("$Name returned $LASTEXITCODE")}
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    if($RepairAppInstaller -and -not $Repair){throw '-RepairAppInstaller must be used together with -Repair.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null
    Start-Transcript -Path (Join-Path $runPath 'Transcript.txt') -Force|Out-Null
    $transcript=$true

    Get-AppxPackage -Name Microsoft.WindowsStore,Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue|
        Select-Object Name,Version,Status,InstallLocation,PackageFullName|
        Export-Csv (Join-Path $runPath 'Packages-Before.csv') -NoTypeInformation

    Get-Service ClipSVC,AppXSvc,InstallService -ErrorAction SilentlyContinue|
        Select-Object Name,Status,StartType|
        Export-Csv (Join-Path $runPath 'Services-Before.csv') -NoTypeInformation

    if(Get-Command winget.exe -ErrorAction SilentlyContinue){winget.exe --info 2>&1|Out-File (Join-Path $runPath 'WingetInfo.txt')}
    else{$warnings.Add('WinGet was not found.')}

    if($Repair -and $PSCmdlet.ShouldProcess('Microsoft Store cache','Run WSReset')){
        $process=Start-Process -FilePath 'wsreset.exe' -PassThru -Wait
        if($process.ExitCode -ne 0){$warnings.Add("WSReset returned $($process.ExitCode)")}
    }

    if($Repair -and $PSCmdlet.ShouldProcess('Microsoft Store package','Re-register package')){
        Register-Package 'Microsoft.WindowsStore'
    }

    if($Repair -and $RepairAppInstaller -and $PSCmdlet.ShouldProcess('App Installer package','Re-register package')){
        Register-Package 'Microsoft.DesktopAppInstaller'
    }

    if($Repair -and (Get-Command winget.exe -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess('WinGet sources','Reset and update sources')){
        Invoke-WingetSource 'WingetSourceReset' @('source','reset','--force','--disable-interactivity')
        Invoke-WingetSource 'WingetSourceUpdate' @('source','update','--disable-interactivity')
    }

    $afterPackages=@(Get-AppxPackage -Name Microsoft.WindowsStore,Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue)
    $afterPackages|Select-Object Name,Version,Status,InstallLocation,PackageFullName|
        Export-Csv (Join-Path $runPath 'Packages-After.csv') -NoTypeInformation
    Get-Service ClipSVC,AppXSvc,InstallService -ErrorAction SilentlyContinue|
        Select-Object Name,Status,StartType|
        Export-Csv (Join-Path $runPath 'Services-After.csv') -NoTypeInformation

    if($Repair -and -not($afterPackages|Where-Object Name -eq 'Microsoft.WindowsStore')){
        $warnings.Add('Microsoft Store package was not verified for the current user after repair.')
    }
    if($Repair -and $RepairAppInstaller -and -not($afterPackages|Where-Object Name -eq 'Microsoft.DesktopAppInstaller')){
        $warnings.Add('App Installer package was not verified for the current user after repair.')
    }

    $warnings|Out-File (Join-Path $runPath 'Warnings.txt') -Encoding UTF8
    if($transcript){Stop-Transcript|Out-Null;$transcript=$false}
    if($warnings.Count -gt 0){Write-Host "[WARN] Completed with warnings. Logs: $runPath" -ForegroundColor Yellow;exit 2}
    Write-Host "[OK] Completed. Logs: $runPath" -ForegroundColor Green;exit 0
}catch{
    if($transcript){try{Stop-Transcript|Out-Null}catch{}}
    Write-Error $_.Exception.Message;exit 1
}
