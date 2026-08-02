$ScriptRoot = Split-Path -Path $PSScriptRoot -Parent

@{
     DatabasePath    = "$ScriptRoot\Data\Database.db"

     HousekeepingIntervals  = 30
     LogRetentionDays       = 190
     AlertRetentionDays     = 370
}