function New-DatabaseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DatabasePath
    )    

    [Database]::new($DatabasePath)
}

function Write-DatabaseLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [string]$Level = "Info",

        [Parameter(Mandatory)]
        [string]$Message               
    )    

    $Database.WriteLog($Level, $Message)
}

function Update-DatabaseWithAlerts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [Parameter(Mandatory)]
        [System.Collections.Generic.List[Alert]]$Alerts
    )

    foreach ($alert in $Alerts) {
        try {
            switch ($alert.Status) {
                "New" {
                    $Database.AddAlert($alert)
                }

                "Resolved" {
                    $Database.ResolveAlert($alert)
                }
            }
        }
        catch {
            $Database.WriteLog(
                "Error",
                "Failed to store alert from $($alert.Source): $($_.Exception.Message)"
            )
        }
    }
}