# Microsoft Store Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

## One-click use

1. Extract the repository while signed in as the affected Windows user.
2. Double-click `Run-OneClick.bat`.
3. Wait for the supported repair sequence to finish.
4. Review the exit code and logs in `C:\ProgramData\MicrosoftStoreRepair\Logs`.

The launcher runs `Repair-MicrosoftStore.ps1` with Store and App Installer repair enabled. There is no menu.

## PowerShell usage

```powershell
.\Repair-MicrosoftStore.ps1
.\Repair-MicrosoftStore.ps1 -Repair
.\Repair-MicrosoftStore.ps1 -Repair -RepairAppInstaller
.\Repair-MicrosoftStore.ps1 -Repair -RepairAppInstaller -WhatIf
```

The script reports package, service and WinGet health, performs supported cache and registration actions, and verifies the target packages afterward.

Exit codes: `0` success, `1` fatal error, `2` repair or verification warnings.

Results vary by Windows version, package availability, policy and permissions. MIT License.
