function New-Alert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Message,

        [datetime]$Timestamp = (Get-Date).ToUniversalTime(),

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateRange(1,4)]
        [int]$Severity,

        [string]$CorrelationKey,

        [string]$ConfigItem,

        [ValidateSet("New","Resolved")]
        [string]$Status = "New"
    )

    return [Alert]::new(
        $Title,
        $Message,
        $Timestamp,
        $Source,
        $Severity,
        $CorrelationKey,
        $ConfigItem,
        $Status
    )
}