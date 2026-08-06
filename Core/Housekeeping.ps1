function Invoke-Housekeeping {
    <#
    .SYNOPSIS
        Runs log/alert pruning and database optimization, but only if it's been
        more than $Config.HousekeepingIntervals since the last run.

    .DESCRIPTION
        Checks the LastHousekeepingRun database setting and skips entirely if the
        configured interval hasn't elapsed yet. Otherwise prunes old logs and
        alerts, optimizes the database, and stamps LastHousekeepingRun with the
        current time. Each step is independently try/caught so one failure
        doesn't prevent the others from running.

    .PARAMETER Database
        The Database connection to operate on.

    .PARAMETER Config
        The pipeline config object. Must expose HousekeepingDays, LogRetentionDays,
        and AlertRetentionDays.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [Parameter(Mandatory)]
        [object]$Config
    )

    $lastRunRaw = Get-DatabaseSetting -Database $Database -Key "LastHousekeepingRun"

    $shouldRun = $true

    if ($lastRunRaw) {
        $lastRun = [datetime]::Parse($lastRunRaw, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
        $daysSinceLastRun = ((Get-Date).ToUniversalTime() - $lastRun).TotalDays

        if ($daysSinceLastRun -lt $Config.HousekeepingIntervals) {
            $shouldRun = $false
        }
    }

    if (-not $shouldRun) {
        Write-DatabaseLog -Database $Database -Level "Information" -Source "Housekeeping" `
            -Message "Skipped - last run was $([math]::Round($daysSinceLastRun, 1)) day(s) ago (interval: $($Config.HousekeepingIntervals) days)."
        return
    }

    try {
        $removedLogs = Remove-DatabaseLogs -Database $Database -OlderThanDays $Config.LogRetentionDays
        Write-DatabaseLog -Database $Database -Level "Information" -Source "Housekeeping" `
            -Message "Removed $removedLogs old log row(s) (retention: $($Config.LogRetentionDays) days)."
    }
    catch {
        Write-DatabaseLog -Database $Database -Level "Error" -Source "Housekeeping" `
            -Message "Failed to remove old logs (retention: $($Config.LogRetentionDays) days): $($_.Exception.Message)"
    }

    try {
        $removedAlerts = Remove-DatabaseAlerts -Database $Database -OlderThanDays $Config.AlertRetentionDays
        Write-DatabaseLog -Database $Database -Level "Information" -Source "Housekeeping" `
            -Message "Removed $removedAlerts old alert row(s) (retention: $($Config.AlertRetentionDays) days)."
    }
    catch {
        Write-DatabaseLog -Database $Database -Level "Error" -Source "Housekeeping" `
            -Message "Failed to remove old alerts (retention: $($Config.AlertRetentionDays) days): $($_.Exception.Message)"
    }

    try {
        Optimize-Database -Database $Database
    }
    catch {
        Write-DatabaseLog -Database $Database -Level "Error" -Source "Housekeeping" `
            -Message "Failed to optimize database: $($_.Exception.Message)"
    }

    Set-DatabaseSetting -Database $Database -Key "LastHousekeepingRun" -Value (Get-Date).ToUniversalTime().ToString("o")
}
