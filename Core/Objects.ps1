class Alert {
    [string]$Title
    [string]$Message
    [datetime]$Timestamp
    [string]$Source
    [int]$Severity
    [string]$CorrelationKey
    [string]$ConfigItem
    [string]$Status

    Alert(
        [string]$Title,
        [string]$Message,
        [datetime]$Timestamp,
        [string]$Source,
        [int]$Severity,
        [string]$CorrelationKey,
        [string]$ConfigItem,
        [string]$Status
    ) {
        $this.Title          = $Title
        $this.Message        = $Message
        $this.Timestamp      = $Timestamp
        $this.Source         = $Source
        $this.Severity       = $Severity
        $this.CorrelationKey = $CorrelationKey
        $this.ConfigItem     = $ConfigItem
        $this.Status         = $Status
    }
}