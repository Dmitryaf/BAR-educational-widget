<#
.SYNOPSIS
Queries the public BAR replay catalog without downloading replay files.

.DESCRIPTION
Search output is normalized from the smaller list schema. Missing optional
fields stay null. When player or map filters are present, returned rows are
validated locally because the server does not guarantee AND semantics across
filter groups. Server pagination still happens before that validation.

.EXAMPLE
.\tools\query_bar_replays.ps1 -Player ExamplePlayer -Limit 20 -AsJson

.EXAMPLE
.\tools\query_bar_replays.ps1 -ReplayId 00000000000000000000000000000000 -AsJson
#>
[CmdletBinding(DefaultParameterSetName = "Search")]
param(
    [Parameter(ParameterSetName = "Search")]
    [string[]] $Player,

    [Parameter(ParameterSetName = "Search")]
    [string[]] $Map,

    [Parameter(ParameterSetName = "Search")]
    [string] $Preset = "duel",

    [Parameter(ParameterSetName = "Search")]
    [Nullable[bool]] $HasBots = $false,

    [Parameter(ParameterSetName = "Search")]
    [Nullable[bool]] $EndedNormally = $true,

    [Parameter(ParameterSetName = "Search")]
    [ValidateRange(1, 100000)]
    [int] $Page = 1,

    [Parameter(ParameterSetName = "Search")]
    [ValidateRange(1, 100)]
    [int] $Limit = 10,

    [Parameter(Mandatory = $true, ParameterSetName = "Detail")]
    [ValidatePattern("^[0-9a-fA-F]{32}$")]
    [string] $ReplayId,

    [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$apiBaseUri = "https://api.bar-rts.com"
$demoStorageBaseUri = "https://storage.uk.cloud.ovh.net/v1/AUTH_10286efc0d334efd917d476d7183232e/BAR/demos"
$headers = @{
    Accept = "application/json"
    "User-Agent" = "BAR-Learning-Coach-Replay-Research/1.0"
}

function Get-OptionalProperty {
    param(
        [AllowNull()]
        [object] $InputObject,
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Convert-ToNullableSeconds {
    param([AllowNull()][object] $Milliseconds)

    if ($null -eq $Milliseconds) {
        return $null
    }

    $parsed = 0.0
    if (-not [double]::TryParse(
        [string] $Milliseconds,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref] $parsed
    )) {
        return $null
    }

    return $parsed / 1000.0
}

function Add-QueryValue {
    param(
        [System.Collections.Generic.List[string]] $Parts,
        [string] $Name,
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) {
        return
    }

    $encodedName = [uri]::EscapeDataString($Name)
    $encodedValue = [uri]::EscapeDataString([string] $Value)
    $Parts.Add("$encodedName=$encodedValue")
}

function Invoke-BarReplayApi {
    param([uri] $Uri)

    try {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers
    }
    catch {
        throw "BAR replay API request failed for $Uri`: $($_.Exception.Message)"
    }
}

function Convert-AllyTeams {
    param([AllowNull()][object] $AllyTeams)

    $teams = @()
    foreach ($team in @($AllyTeams)) {
        if ($null -eq $team) {
            continue
        }

        $players = @()
        foreach ($player in @(Get-OptionalProperty -InputObject $team -Name "Players")) {
            if ($null -eq $player) {
                continue
            }

            $players += [pscustomobject]@{
                Name = Get-OptionalProperty -InputObject $player -Name "name"
                UserId = Get-OptionalProperty -InputObject $player -Name "userId"
                TeamId = Get-OptionalProperty -InputObject $player -Name "teamId"
                Faction = Get-OptionalProperty -InputObject $player -Name "faction"
                Skill = Get-OptionalProperty -InputObject $player -Name "skill"
                SkillUncertainty = Get-OptionalProperty -InputObject $player -Name "skillUncertainty"
            }
        }

        $ais = @()
        foreach ($ai in @(Get-OptionalProperty -InputObject $team -Name "AIs")) {
            if ($null -eq $ai) {
                continue
            }

            $ais += [pscustomobject]@{
                Name = Get-OptionalProperty -InputObject $ai -Name "name"
                ShortName = Get-OptionalProperty -InputObject $ai -Name "shortName"
                TeamId = Get-OptionalProperty -InputObject $ai -Name "teamId"
                Faction = Get-OptionalProperty -InputObject $ai -Name "faction"
            }
        }

        $teams += [pscustomobject]@{
            AllyTeamId = Get-OptionalProperty -InputObject $team -Name "allyTeamId"
            WinningTeam = Get-OptionalProperty -InputObject $team -Name "winningTeam"
            Players = $players
            AIs = $ais
        }
    }

    return $teams
}

function Convert-ReplaySummary {
    param([object] $Replay)

    $map = Get-OptionalProperty -InputObject $Replay -Name "Map"
    return [pscustomobject]@{
        Id = Get-OptionalProperty -InputObject $Replay -Name "id"
        StartTimeUtc = Get-OptionalProperty -InputObject $Replay -Name "startTime"
        DurationSeconds = Convert-ToNullableSeconds (Get-OptionalProperty -InputObject $Replay -Name "durationMs")
        Map = [pscustomobject]@{
            ScriptName = Get-OptionalProperty -InputObject $map -Name "scriptName"
            FileName = Get-OptionalProperty -InputObject $map -Name "fileName"
        }
        AllyTeams = Convert-AllyTeams (Get-OptionalProperty -InputObject $Replay -Name "AllyTeams")
    }
}

function Convert-ReplayDetail {
    param([object] $Replay)

    $fileName = Get-OptionalProperty -InputObject $Replay -Name "fileName"
    $map = Get-OptionalProperty -InputObject $Replay -Name "Map"
    $downloadUri = if ([string]::IsNullOrWhiteSpace([string] $fileName)) {
        $null
    }
    else {
        "$demoStorageBaseUri/$([uri]::EscapeDataString([string] $fileName))"
    }

    return [pscustomobject]@{
        Id = Get-OptionalProperty -InputObject $Replay -Name "id"
        FileName = $fileName
        DownloadUri = $downloadUri
        EngineVersion = Get-OptionalProperty -InputObject $Replay -Name "engineVersion"
        GameVersion = Get-OptionalProperty -InputObject $Replay -Name "gameVersion"
        StartTimeUtc = Get-OptionalProperty -InputObject $Replay -Name "startTime"
        DurationSeconds = Convert-ToNullableSeconds (Get-OptionalProperty -InputObject $Replay -Name "durationMs")
        FullDurationSeconds = Convert-ToNullableSeconds (Get-OptionalProperty -InputObject $Replay -Name "fullDurationMs")
        EndedNormally = Get-OptionalProperty -InputObject $Replay -Name "gameEndedNormally"
        HasBots = Get-OptionalProperty -InputObject $Replay -Name "hasBots"
        Preset = Get-OptionalProperty -InputObject $Replay -Name "preset"
        Map = [pscustomobject]@{
            Id = Get-OptionalProperty -InputObject $map -Name "id"
            ScriptName = Get-OptionalProperty -InputObject $map -Name "scriptName"
            FileName = Get-OptionalProperty -InputObject $map -Name "fileName"
            Width = Get-OptionalProperty -InputObject $map -Name "width"
            Height = Get-OptionalProperty -InputObject $map -Name "height"
        }
        AllyTeams = Convert-AllyTeams (Get-OptionalProperty -InputObject $Replay -Name "AllyTeams")
    }
}

function Test-ReplaySummaryMatches {
    param(
        [object] $Replay,
        [string[]] $RequestedPlayers,
        [string[]] $RequestedMaps
    )

    if ($null -ne $RequestedPlayers -and $RequestedPlayers.Length -gt 0) {
        $replayPlayerNames = @(
            foreach ($team in @($Replay.AllyTeams)) {
                foreach ($replayPlayer in @($team.Players)) {
                    if ($null -ne $replayPlayer.Name) {
                        [string] $replayPlayer.Name
                    }
                }
            }
        )
        $matchesPlayer = $false
        foreach ($requestedPlayer in @($RequestedPlayers)) {
            if ($replayPlayerNames -contains $requestedPlayer) {
                $matchesPlayer = $true
                break
            }
        }
        if (-not $matchesPlayer) {
            return $false
        }
    }

    if ($null -ne $RequestedMaps -and $RequestedMaps.Length -gt 0) {
        $replayMapNames = @($Replay.Map.ScriptName, $Replay.Map.FileName)
        $matchesMap = $false
        foreach ($requestedMap in @($RequestedMaps)) {
            if ($replayMapNames -contains $requestedMap) {
                $matchesMap = $true
                break
            }
        }
        if (-not $matchesMap) {
            return $false
        }
    }

    return $true
}

if ($PSCmdlet.ParameterSetName -eq "Detail") {
    $uri = [uri] "$apiBaseUri/replays/$($ReplayId.ToLowerInvariant())"
    $response = Invoke-BarReplayApi -Uri $uri
    $result = Convert-ReplayDetail -Replay $response
    $result | Add-Member -NotePropertyName SourceUri -NotePropertyValue ([string] $uri)
}
else {
    $queryParts = [System.Collections.Generic.List[string]]::new()
    Add-QueryValue -Parts $queryParts -Name "page" -Value $Page
    Add-QueryValue -Parts $queryParts -Name "limit" -Value $Limit
    Add-QueryValue -Parts $queryParts -Name "preset" -Value $Preset

    if ($null -ne $HasBots) {
        Add-QueryValue -Parts $queryParts -Name "hasBots" -Value ([bool] $HasBots).ToString().ToLowerInvariant()
    }
    if ($null -ne $EndedNormally) {
        Add-QueryValue -Parts $queryParts -Name "endedNormally" -Value ([bool] $EndedNormally).ToString().ToLowerInvariant()
    }
    foreach ($name in @($Player)) {
        Add-QueryValue -Parts $queryParts -Name "players" -Value $name
    }
    foreach ($name in @($Map)) {
        Add-QueryValue -Parts $queryParts -Name "maps" -Value $name
    }

    $uri = [uri] "$apiBaseUri/replays?$($queryParts -join '&')"
    $response = Invoke-BarReplayApi -Uri $uri
    $data = Get-OptionalProperty -InputObject $response -Name "data"
    if ($null -eq $data) {
        throw "BAR replay API search response does not contain a data field"
    }

    $serverReplays = @($data | ForEach-Object { Convert-ReplaySummary -Replay $_ })
    $replays = @(
        $serverReplays | Where-Object {
            Test-ReplaySummaryMatches -Replay $_ -RequestedPlayers $Player -RequestedMaps $Map
        }
    )
    $result = [pscustomobject]@{
        SourceUri = [string] $uri
        Page = Get-OptionalProperty -InputObject $response -Name "page"
        Limit = Get-OptionalProperty -InputObject $response -Name "limit"
        TotalResults = Get-OptionalProperty -InputObject $response -Name "totalResults"
        ServerResultCount = $serverReplays.Count
        ReturnedResultCount = $replays.Count
        LocalFilterApplied = (
            ($null -ne $Player -and $Player.Length -gt 0) -or
            ($null -ne $Map -and $Map.Length -gt 0)
        )
        LocalIntersectionApplied = (
            $null -ne $Player -and $Player.Length -gt 0 -and
            $null -ne $Map -and $Map.Length -gt 0
        )
        Replays = $replays
    }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    $result
}
