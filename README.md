# Microsoft Store Repair

> **Testing note:** This was tested by me to be working. User experience may vary.

Included script: `Repair-MicrosoftStore.ps1`

```powershell
.\Repair-MicrosoftStore.ps1
.\Repair-MicrosoftStore.ps1 -Repair
.\Repair-MicrosoftStore.ps1 -Repair -RepairAppInstaller
```

The script reports Windows package health and provides optional repair actions with `-WhatIf` support. Logs are written to `C:\ProgramData\MicrosoftStoreRepair\Logs`.

Exit codes: `0` success, `1` fatal error, `2` completed with warnings.

Use this project at your own risk. Results vary by Windows version, policy and permissions.

MIT License.
