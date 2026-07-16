<#
.SYNOPSIS
    Entry point for the scheduled task. Runs every script in Sources\, combines
    the results, stores them, then runs every script in Outputs\.

.NOTES
    Plugin contract — every plugin is a standalone script, no function wrapper needed:
      Sources\*.ps1  param($Config)          -> returns [object[]] (New-Alert shape)
      Outputs\*.ps1  param($Alerts, $Config) -> no return value (side-effecting)

    Adding a new source or output = dropping a new .ps1 file in the folder.
    Nothing here needs to change.

    All discovery/execution/error-handling for plugins lives in Core\Plugin.ps1 —
    see Invoke-Plugins there for how Sources (accumulate) and Outputs
    (fire-and-forget) each get run.
#>

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1. Config + shared dependencies
# ---------------------------------------------------------------------------
<#
$Devconfig = & ".\Config\Config.ps1"

. ".\Core\Objects.ps1"
. ".\Core\ObjectsHelper.ps1"
. ".\Core\Database.ps1"
. ".\Core\DatabaseHelper.ps1"
. ".\Core\Plugins.ps1"

$DevDatabase = [Database]::new($Devconfig.DatabasePath)
#>

$config = & "$PSScriptRoot\Config\Config.ps1"

. "$PSScriptRoot\Core\Objects.ps1"
. "$PSScriptRoot\Core\ObjectsHelper.ps1"
. "$PSScriptRoot\Core\Database.ps1"
. "$PSScriptRoot\Core\DatabaseHelper.ps1"
. "$PSScriptRoot\Core\Plugins.ps1"

$Database = New-DatabaseConnection -DatabasePath $config.DatabasePath

# ---------------------------------------------------------------------------
# 2. Sources — collect new alerts from every source, combined into one batch
# ---------------------------------------------------------------------------
$Alerts = Invoke-Plugins -Folder "$PSScriptRoot\Sources" -Parameters @{ Config = $config } -Accumulate -Database $Database

# ---------------------------------------------------------------------------
# 3. No Further Processing required if no Alerts were sources
# ---------------------------------------------------------------------------
if($null -eq $Alerts){
    return
}

# ---------------------------------------------------------------------------
# 4. Process - Save and Update Alerts in the Database
# ---------------------------------------------------------------------------
Update-DatabaseWithAlerts -Database $Database -Alerts $Alerts

# ---------------------------------------------------------------------------
# 5. Outputs — dispatch the final batch, one call per output plugin
# ---------------------------------------------------------------------------
Invoke-Plugins -Folder "$PSScriptRoot\Outputs" -Parameters @{ Alerts = $Alerts; Config = $config } -Database $Database | Out-Null

Write-DatabaseLog -Database $Database -Level "Info" -Message "Cycle completed: Alerts stored, dispatched to outputs"