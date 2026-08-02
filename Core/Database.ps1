<#
.SYNOPSIS
    SQLite-based alert storage.

.NOTES
    Requires the PSSQLite module:
        Install-Module PSSQLite -Scope CurrentUser

    Dot-source this file so the AlertStore class persists in the caller's scope:
        . "$PSScriptRoot\AlertStore.ps1"
#>

if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
    throw "PSSQLite module not found. Install with: Install-Module PSSQLite -Scope CurrentUser"
}
Import-Module PSSQLite

class Database {
    [string]$DbPath

    Database([string]$DbPath) {
        $this.DbPath = $DbPath
        $this.Initialize()
    }

    # ---- Schema setup — safe to call every time, CREATE TABLE IF NOT EXISTS ----

    [void] Initialize() {
        $sql = @"
CREATE TABLE IF NOT EXISTS alerts (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    Title           TEXT,
    Message         TEXT,
    Timestamp       TEXT,
    Source          TEXT,
    Severity        INTEGER,
    CorrelationKey  TEXT,
    ConfigItem      TEXT,
    Resolved        INTEGER  DEFAULT 0,
    ResolvedTime    TEXT
);

CREATE TABLE IF NOT EXISTS logs (
    Id        INTEGER PRIMARY KEY AUTOINCREMENT,
    Timestamp TEXT,
    Level     TEXT,
    Source    TEXT,
    Message   TEXT 
);

CREATE TABLE IF NOT EXISTS settings (
    Key       TEXT PRIMARY KEY,
    Value     TEXT,
    UpdatedAt TEXT
);

CREATE INDEX IF NOT EXISTS idx_alerts_timestamp  ON alerts(Timestamp);
CREATE INDEX IF NOT EXISTS idx_alerts_severity   ON alerts(Severity);
CREATE INDEX IF NOT EXISTS idx_alerts_resolved   ON alerts(Resolved);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp    ON logs(Timestamp);
CREATE INDEX IF NOT EXISTS idx_logs_source       ON logs(Source);

-- WAL mode = better concurrent read/write behavior across processes
PRAGMA journal_mode=WAL;
"@
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql
    }

    # ---- Alerts ----

    [void] AddAlert([Alert]$Alert) {
        $this.AddAlert($Alert, $Alert.Timestamp.ToUniversalTime().ToString("o"), $false, $null)
    }

    [void] AddAlert([Alert]$Alert, [string]$Timestamp, [bool]$Resolved, [string]$ResolvedTime) {
        $sql = "INSERT INTO alerts (Title, Message, Timestamp, Source, Severity, CorrelationKey, ConfigItem, Resolved, ResolvedTime) VALUES (@Title, @Message, @Timestamp, @Source, @Severity, @CorrelationKey, @ConfigItem, @Resolved, @ResolvedTime)"
        $params = @{
            Title          = $Alert.Title
            Message        = $Alert.Message
            Timestamp      = $Timestamp
            Source         = $Alert.Source
            Severity       = $Alert.Severity
            CorrelationKey = $Alert.CorrelationKey
            ConfigItem     = $Alert.ConfigItem
            Resolved       = [int]$Resolved
            ResolvedTime   = $ResolvedTime
        }
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters $params
    }

    [void] ResolveAlert([Alert]$Alert) {
        $timestamp = $Alert.Timestamp.ToUniversalTime().ToString("o")
    
        $findSql = "SELECT Id FROM alerts WHERE CorrelationKey = @CorrelationKey AND Timestamp <= @Timestamp AND Resolved = 0 ORDER BY Timestamp ASC LIMIT 1"
        $params = @{
            CorrelationKey = $Alert.CorrelationKey
            Timestamp      = $timestamp
        }
    
        $match = Invoke-SqliteQuery -DataSource $this.DbPath -Query $findSql -SqlParameters $params
    
        if ($match) {
            $updateSql = "UPDATE alerts SET Resolved = 1, ResolvedTime = @Timestamp WHERE Id = @Id"
            Invoke-SqliteQuery -DataSource $this.DbPath -Query $updateSql -SqlParameters @{
                Id        = $match.Id
                Timestamp = $timestamp
            }
        }
        else {
            $this.WriteLog("Warning", "Database", "Resolve received with no matching open alert. CorrelationKey=$($Alert.CorrelationKey). Inserting orphan row.")
            $this.AddAlert($Alert, $null, $true, $timestamp)
        }
    }

    [object[]] GetUnresolvedAlerts() {
        $sql = "SELECT * FROM alerts WHERE Resolved = 0 ORDER BY Timestamp DESC"
        return Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql
    }

    [object[]] GetAlerts() {
        $sql = "SELECT * FROM alerts ORDER BY Timestamp DESC"
        return Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql
    }

    # ---- App Registry ----

    [void] SetSetting([string]$Key, [string]$Value) {
        $sql = "INSERT INTO settings (Key, Value, UpdatedAt) VALUES (@Key, @Value, @UpdatedAt) ON CONFLICT(Key) DO UPDATE SET Value = excluded.Value, UpdatedAt = excluded.UpdatedAt;"
        $params = @{
            Key       = $Key
            Value     = $Value
            UpdatedAt = (Get-Date).ToUniversalTime().ToString("o")
        }
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters $params
    }

    [string] GetSetting([string]$Key) {
        $sql = "SELECT Value FROM settings WHERE Key = @Key"
        $result = Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters @{ Key = $Key }
        if ($result) {
            return $result.Value
        }
        return $null
    }

    # ---- Logs ----

    [void] WriteLog([string]$Level, [string]$Source, [string]$Message) {
        $sql = "INSERT INTO logs (Timestamp, Level, Source, Message) VALUES (@Timestamp, @Level, @Source, @Message)"
        $params = @{
            Timestamp = (Get-Date).ToUniversalTime().ToString("o")
            Level     = $Level
            Source    = $Source
            Message   = $Message
        }
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters $params
    }

    [object[]] GetRecentLogs([int]$Count) {
        $sql = "SELECT * FROM logs ORDER BY Timestamp DESC LIMIT @Count"
        return Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters @{ Count = $Count }
    }

    # ---- Cleanup ----

    [int] PruneLogs([int]$OlderThanDays) {
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays).ToString("o")
        $conn = New-SQLiteConnection -DataSource $this.DbPath
        try {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query "DELETE FROM logs WHERE Timestamp < @Cutoff" -SqlParameters @{ Cutoff = $cutoff }
            $count = Invoke-SqliteQuery -SQLiteConnection $conn -Query "SELECT changes() AS Count"
            return $count.Count
        }
        finally {
            $conn.Close()
        }
    }

    [int] PruneAlerts([int]$OlderThanDays) {
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays).ToString("o")
        $conn = New-SQLiteConnection -DataSource $this.DbPath
        try {
            Invoke-SqliteQuery -SQLiteConnection $conn -Query "DELETE FROM alerts WHERE Timestamp < @Cutoff" -SqlParameters @{ Cutoff = $cutoff }
            $count = Invoke-SqliteQuery -SQLiteConnection $conn -Query "SELECT changes() AS Count"
            return $count.Count
        }
        finally {
            $conn.Close()
        }
    }

    [void] CompactDatabase() {
        Invoke-SqliteQuery -DataSource $this.DbPath -Query "VACUUM;"
    }
}
