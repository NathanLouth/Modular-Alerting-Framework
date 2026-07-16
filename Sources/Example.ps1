<#
.SYNOPSIS
    Source plugin — flat script, receives $Config, must output/return a list of
    Alert objects (or an empty list if there's nothing to return).
    Filename is used as the plugin's identity in logs, so keep it descriptive.
#>

param(
    [Parameter(Mandatory)]
    [hashtable]$Config
)

$Alerts = [System.Collections.Generic.List[Alert]]::new()

$Alerts.Add(
    (New-Alert `
        -Title "Disk Space Low" `
        -Message "Drive C: is below 10% free." `
        -Source "DiskMonitor" `
        -Severity 3 `
        -CorrelationKey "SERVER01-C" `
        -ConfigItem "SERVER01")
)

$Alerts.Add(
    (New-Alert `
        -Title "Disk Space Low" `
        -Message "Drive C: is below 10% free." `
        -Source "DiskMonitor" `
        -Severity 3 `
        -CorrelationKey "SERVER02-C" `
        -ConfigItem "SERVER02")
)

$Alerts.Add(
    (New-Alert `
        -Title "Disk Space Low" `
        -Message "Drive C: is below 10% free." `
        -Source "DiskMonitor" `
        -Severity 3 `
        -CorrelationKey "SERVER03-C" `
        -ConfigItem "SERVER03" `
        -Timestamp "2026-07-14 09:00")
)

$Alerts.Add(
    (New-Alert `
        -Title "Disk Space Low" `
        -Message "Drive C: is below 10% free." `
        -Source "DiskMonitor" `
        -Severity 3 `
        -CorrelationKey "SERVER03-C" `
        -ConfigItem "SERVER03" `
        -Status "Resolved" `
        -Timestamp "2026-07-14 10:00")
)

return ,$Alerts