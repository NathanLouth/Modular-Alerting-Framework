$ScriptRoot = Split-Path -Path $PSScriptRoot -Parent

@{
    DatabasePath    = "$ScriptRoot\Data\Database.db"
}