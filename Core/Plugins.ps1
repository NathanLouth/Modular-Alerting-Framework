<#
.SYNOPSIS
    Plugin discovery + execution. Every Source/Logic/Output folder is just a set of
    standalone .ps1 files with their own param() blocks — this file is the one place
    that knows how to find them, run them in order, and handle their output/failures.

.NOTES
    Each plugin script is invoked via & (call operator), which runs it in its own
    isolated child scope — no dot-sourcing, no function-name collisions possible,
    since nothing is injected into a shared scope.

    Plugin scripts require no special setup — no [CmdletBinding()], no imports.
    They just declare a plain param() block for whatever config values they need
    (and, for Output plugins, $Alerts). Write-Warning and Write-Information calls
    are captured automatically via -WarningVariable/-InformationVariable, which
    work on any script with a param() block regardless of [CmdletBinding()].
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
    Optional database used for logging plugin failures, warnings, and information.
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
        $warnings = $null
        $infos    = $null

        try {
            $output = & $file.FullName @Parameters `
                -WarningVariable warnings -WarningAction SilentlyContinue `
                -InformationVariable infos -InformationAction SilentlyContinue

            foreach ($w in $warnings) {
                if ($Database) {
                    Write-DatabaseLog -Database $Database -Level "Warning" -Source $file.BaseName -Message $w.Message
                }
                else {
                    Write-Warning "[$($file.BaseName)] $($w.Message)"
                }
            }

            foreach ($i in $infos) {
                if ($Database) {
                    Write-DatabaseLog -Database $Database -Level "Information" -Source $file.BaseName -Message $i.MessageData
                }
                else {
                    Write-Information "[$($file.BaseName)] $($i.MessageData)"
                }
            }

            $outputArray = if ($null -eq $output) { @() } else { @($output) }
            
            # Only keep genuine Alert instances — drop stray strings/bools/PSCustomObjects/etc.
            # that a plugin might accidentally leave on the success stream.
            $filteredOutput = @($outputArray | Where-Object { $_ -is [Alert] })
            
            $droppedCount = $outputArray.Count - $filteredOutput.Count
            if ($droppedCount -gt 0 -and $Database) {
                Write-DatabaseLog -Database $Database -Level "Warning" -Source $file.BaseName `
                    -Message "Emitted $droppedCount non-Alert object(s) on the output stream; discarded."
            }

            if ($ChainParameterName) {
                $Parameters[$ChainParameterName] = $filteredOutput
            }
            elseif ($Accumulate -and $filteredOutput) {
                foreach ($alert in $filteredOutput) {
                    $collected.Add($alert)
                }
            }
        }
        catch {
            $message = "Plugin '$($file.BaseName)' in '$Folder' failed: $($_.Exception.Message)"

            if ($Database) {
                Write-DatabaseLog -Database $Database -Level "Error" -Source $file.BaseName -Message $message
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
