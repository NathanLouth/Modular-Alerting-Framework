<#
.SYNOPSIS
    Output plugin — receives the alerts for this run plus $Config.
    No return value expected — this is a side-effecting step (sends notifications).
#>

param(
    [Parameter(Mandatory)]
    [System.Collections.Generic.List[Alert]]$Alerts,

    [Parameter(Mandatory)]
    [hashtable]$Config
)

foreach ($alert in $Alerts | Sort-Object Timestamp) {

    if ($alert.Status -eq "Resolved") {
        Write-Host "[RESOLVED] **[$($alert.Severity)] $($alert.Source)** $($alert.Message)"
    }
    else {
        Write-Host "**[$($alert.Severity)] $($alert.Source)** $($alert.Message)"
    }
}