<#
.SYNOPSIS
    Plugin discovery + execution. Every Source/Logic/Output folder is just a set of
    standalone .ps1 files with their own param() blocks — this file is the one place
    that knows how to find them, run them in order, and handle their output/failures.

.NOTES
    Each plugin script is invoked via & (call operator), which runs it in its own
    isolated child scope — no dot-sourcing, no function-name collisions possible,
    since nothing is injected into a shared scope.
#>

function Get-PluginFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    Get-ChildItem -Path $Folder -Filter "*.ps1" -ErrorAction SilentlyContinue |
        Sort-Object Name
}

<#
.SYNOPSIS
    Runs every plugin script in a folder and returns the combined result.

.PARAMETER Folder
    Path to the plugin folder (Sources\, Logic\, or Outputs\).

.PARAMETER Parameters
    Hashtable of named parameters passed into every plugin script.

.PARAMETER ChainParameterName
    If set, each script's output replaces this parameter before the next script runs.
    Used for Logic plugins.

.PARAMETER Accumulate
    If set, each plugin result is combined into a single Alert list.
    Used for Source plugins.

.PARAMETER Database
    Optional database used for logging plugin failures.
#>
function Invoke-Plugins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Folder,

        [hashtable]$Parameters = @{},

        [string]$ChainParameterName,

        [switch]$Accumulate,

        [Database]$Database
    )

    if ($Accumulate) {
        $collected = [System.Collections.Generic.List[Alert]]::new()
    }

    foreach ($file in (Get-PluginFiles -Folder $Folder)) {
        try {
            $output = & $file.FullName @Parameters

            if ($ChainParameterName) {
                $Parameters[$ChainParameterName] = @($output)
            }
            elseif ($Accumulate -and $output) {
                foreach ($alert in $output) {
                    $collected.Add($alert)
                }
            }
        }
        catch {
            $message = "Plugin '$($file.BaseName)' in '$Folder' failed: $($_.Exception.Message)"

            if ($Database) {
                $Database.WriteLog("Error", $message)
            }
            else {
                Write-Warning $message
            }
        }
    }

    if ($ChainParameterName) {
        return $Parameters[$ChainParameterName]
    }

    if ($Accumulate) {
        return $collected
    }

    return $null
}