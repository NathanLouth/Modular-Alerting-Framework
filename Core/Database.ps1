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
    Title           TEXT NOT NULL,
    Message         TEXT NOT NULL,
    Timestamp       TEXT NOT NULL,
    Source          TEXT NOT NULL,
    Severity        INTEGER NOT NULL,
    CorrelationKey  TEXT,
    ConfigItem      TEXT,
    Resolved        INTEGER NOT NULL DEFAULT 0,
    ResolvedTime    TEXT
);

CREATE TABLE IF NOT EXISTS logs (
    Id        INTEGER PRIMARY KEY AUTOINCREMENT,
    Timestamp TEXT NOT NULL,
    Level     TEXT NOT NULL,
    Message   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_alerts_timestamp ON alerts(Timestamp);
CREATE INDEX IF NOT EXISTS idx_alerts_severity   ON alerts(Severity);
CREATE INDEX IF NOT EXISTS idx_alerts_resolved   ON alerts(Resolved);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp    ON logs(Timestamp);

-- WAL mode = better concurrent read/write behavior across processes
PRAGMA journal_mode=WAL;
"@
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql
    }

    # ---- Alerts ----

    [void] AddAlert([Alert]$Alert) {
        $sql = "INSERT INTO alerts (Title, Message, Timestamp, Source, Severity, CorrelationKey, ConfigItem, Resolved, ResolvedTime) VALUES (@Title, @Message, @Timestamp, @Source, @Severity, @CorrelationKey, @ConfigItem, 0, NULL)"
        $params = @{
            Title          = $Alert.Title
            Message        = $Alert.Message
            Timestamp      = $Alert.Timestamp.ToUniversalTime().ToString("o")
            Source         = $Alert.Source
            Severity       = $Alert.Severity
            CorrelationKey = $Alert.CorrelationKey
            ConfigItem     = $Alert.ConfigItem

        }
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters $params
    }

    [void] ResolveAlert([Alert]$Alert) {
        $sql = "UPDATE alerts SET Resolved = 1, ResolvedTime = @Timestamp WHERE CorrelationKey = @CorrelationKey AND Timestamp < @Timestamp AND Resolved = 0"

        $params = @{
            CorrelationKey = $Alert.CorrelationKey
            Timestamp      = $Alert.Timestamp.ToUniversalTime().ToString("o")
        }

        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters $params
    }

    [object[]] GetUnresolvedAlerts() {
        $sql = "SELECT * FROM alerts WHERE Resolved = 0 ORDER BY Timestamp DESC"
        return Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql
    }

    [object[]] GetAlerts() {
        $sql = "SELECT * FROM alerts ORDER BY Timestamp DESC"
        return Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql
    }

    # ---- Logs ----

    [void] WriteLog([string]$Level, [string]$Message) {
        $sql = "INSERT INTO logs (Timestamp, Level, Message) VALUES (@Timestamp, @Level, @Message)"
        $params = @{
            Timestamp = (Get-Date).ToUniversalTime().ToString("o")
            Level     = $Level
            Message   = $Message
        }
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters $params
    }

    [object[]] GetRecentLogs([int]$Count) {
        $sql = "SELECT * FROM logs ORDER BY Timestamp DESC LIMIT @Count"
        return Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters @{ Count = $Count }
    }

    # ---- Cleanup ----

    [int] PurgeOldLogs([int]$OlderThanDays) {
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays).ToString("o")
        $sql = "DELETE FROM logs WHERE Timestamp < @Cutoff"
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters @{ Cutoff = $cutoff }
        $count = Invoke-SqliteQuery -DataSource $this.DbPath -Query "SELECT changes() AS Count"
        return $count.Count
    }

    [int] PurgeResolvedAlerts([int]$OlderThanDays) {
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays).ToString("o")
        $sql = "DELETE FROM alerts WHERE Resolved = 1 AND Timestamp < @Cutoff"
        Invoke-SqliteQuery -DataSource $this.DbPath -Query $sql -SqlParameters @{ Cutoff = $cutoff }
        $count = Invoke-SqliteQuery -DataSource $this.DbPath -Query "SELECT changes() AS Count"
        return $count.Count
    }

    [void] CompactDatabase() {
        Invoke-SqliteQuery -DataSource $this.DbPath -Query "VACUUM;"
    }
}