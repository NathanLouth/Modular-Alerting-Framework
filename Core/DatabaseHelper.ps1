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
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Message               
    )    

    $Database.WriteLog($Level, $Source, $Message)
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
            Write-DatabaseLog -Database $Database -Level "Error" -Source "DatabaseHelper" -Message "Failed to store alert from $($alert.Source): $($_.Exception.Message)"
        }
    }
}

function Set-DatabaseSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $Database.SetSetting($Key, $Value)
}

function Get-DatabaseSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [Parameter(Mandatory)]
        [string]$Key
    )

    $Database.GetSetting($Key)
}

function Optimize-Database {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database
    )

    $Database.CompactDatabase()
}

function Remove-DatabaseLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [Parameter(Mandatory)]
        [int]$OlderThanDays   
    )

    $Database.PruneLogs([int]$OlderThanDays)
}

function Remove-DatabaseAlerts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Database]$Database,

        [Parameter(Mandatory)]
        [int]$OlderThanDays   
    )

    $Database.PruneAlerts([int]$OlderThanDays)
}