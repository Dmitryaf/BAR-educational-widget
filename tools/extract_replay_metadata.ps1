param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]] $Path,

    [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$expectedMagic = "spring demofile"
$stableHeaderSize = 352

function Read-FixedString {
    param(
        [System.IO.BinaryReader] $Reader,
        [int] $Length
    )

    $bytes = $Reader.ReadBytes($Length)
    if ($bytes.Length -ne $Length) {
        throw "Unexpected end of replay header"
    }

    return [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
}

function Skip-Bytes {
    param(
        [System.IO.BinaryReader] $Reader,
        [long] $Count
    )

    $buffer = New-Object byte[] 65536
    $remaining = $Count

    while ($remaining -gt 0) {
        $requested = [int][Math]::Min($buffer.Length, $remaining)
        $read = $Reader.Read($buffer, 0, $requested)
        if ($read -le 0) {
            throw "Unexpected end of replay while skipping demo stream"
        }

        $remaining -= $read
    }
}

function Get-SetupValue {
    param(
        [string] $Text,
        [string] $Name
    )

    $escapedName = [regex]::Escape($Name)
    $match = [regex]::Match($Text, "(?im)^\s*$escapedName\s*=\s*(?<value>.*?);\s*$")
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups["value"].Value.Trim()
}

function Convert-ToNullableDouble {
    param([string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $normalized = $Value.Trim().TrimStart("[").TrimEnd("]")
    $parsed = 0.0
    if ([double]::TryParse(
        $normalized,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref] $parsed
    )) {
        return $parsed
    }

    return $null
}

function Convert-ToNullableInt {
    param([string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $parsed = 0
    if ([int]::TryParse($Value, [ref] $parsed)) {
        return $parsed
    }

    return $null
}

function Read-ReplayMetadata {
    param([string] $ReplayPath)

    $resolvedPath = (Resolve-Path -LiteralPath $ReplayPath).Path
    $fileStream = [System.IO.File]::OpenRead($resolvedPath)
    $gzipStream = $null
    $reader = $null

    try {
        $gzipStream = [System.IO.Compression.GZipStream]::new(
            $fileStream,
            [System.IO.Compression.CompressionMode]::Decompress
        )
        $reader = [System.IO.BinaryReader]::new($gzipStream, [System.Text.Encoding]::UTF8, $true)

        $magic = Read-FixedString -Reader $reader -Length 16
        if ($magic -ne $expectedMagic) {
            throw "Unsupported replay magic in $resolvedPath"
        }

        $formatVersion = $reader.ReadInt32()
        $headerSize = $reader.ReadInt32()
        $engineVersion = Read-FixedString -Reader $reader -Length 256
        $gameIdBytes = $reader.ReadBytes(16)
        $unixTime = $reader.ReadUInt64()
        $scriptSize = $reader.ReadInt32()
        $demoStreamSize = $reader.ReadInt32()
        $gameTime = $reader.ReadInt32()
        $wallclockTime = $reader.ReadInt32()
        $numPlayers = $reader.ReadInt32()
        $playerStatSize = $reader.ReadInt32()
        $playerStatElemSize = $reader.ReadInt32()
        $numTeams = $reader.ReadInt32()
        $teamStatSize = $reader.ReadInt32()
        $teamStatElemSize = $reader.ReadInt32()
        $teamStatPeriod = $reader.ReadInt32()
        $winningAllyTeamsSize = $reader.ReadInt32()

        if ($formatVersion -ne 5) {
            throw "Unsupported replay format version $formatVersion in $resolvedPath"
        }
        if ($headerSize -lt $stableHeaderSize) {
            throw "Replay header is smaller than the stable v5 header in $resolvedPath"
        }
        if ($scriptSize -lt 0 -or $demoStreamSize -lt 0 -or $winningAllyTeamsSize -lt 0) {
            throw "Replay contains an invalid negative chunk size in $resolvedPath"
        }

        if ($headerSize -gt $stableHeaderSize) {
            Skip-Bytes -Reader $reader -Count ($headerSize - $stableHeaderSize)
        }

        $setupBytes = $reader.ReadBytes($scriptSize)
        if ($setupBytes.Length -ne $scriptSize) {
            throw "Unexpected end of setup script in $resolvedPath"
        }
        $setupText = [System.Text.Encoding]::UTF8.GetString($setupBytes)

        $teams = @{}
        foreach ($match in [regex]::Matches($setupText, "(?ms)\[team(?<id>\d+)\]\s*\{(?<body>.*?)\}")) {
            $teamId = [int] $match.Groups["id"].Value
            $body = $match.Groups["body"].Value
            $teams[$teamId] = [pscustomobject]@{
                TeamId = $teamId
                AllyTeamId = Convert-ToNullableInt (Get-SetupValue -Text $body -Name "allyteam")
                Side = Get-SetupValue -Text $body -Name "side"
            }
        }

        $players = @()
        foreach ($match in [regex]::Matches($setupText, "(?ms)\[player(?<id>\d+)\]\s*\{(?<body>.*?)\}")) {
            $playerId = [int] $match.Groups["id"].Value
            $body = $match.Groups["body"].Value
            $teamId = Convert-ToNullableInt (Get-SetupValue -Text $body -Name "team")
            $team = if ($null -ne $teamId -and $teams.ContainsKey($teamId)) { $teams[$teamId] } else { $null }

            $players += [pscustomobject]@{
                PlayerId = $playerId
                Name = Get-SetupValue -Text $body -Name "name"
                AccountId = Convert-ToNullableInt (Get-SetupValue -Text $body -Name "accountid")
                TeamId = $teamId
                AllyTeamId = if ($null -ne $team) { $team.AllyTeamId } else { $null }
                Side = if ($null -ne $team) { $team.Side } else { $null }
                Spectator = (Get-SetupValue -Text $body -Name "spectator") -eq "1"
                Skill = Convert-ToNullableDouble (Get-SetupValue -Text $body -Name "skill")
                SkillUncertainty = Convert-ToNullableDouble (Get-SetupValue -Text $body -Name "skilluncertainty")
                CountryCode = Get-SetupValue -Text $body -Name "countrycode"
            }
        }

        $ais = @()
        foreach ($match in [regex]::Matches($setupText, "(?ms)\[ai(?<id>\d+)\]\s*\{(?<body>.*?)\}")) {
            $aiId = [int] $match.Groups["id"].Value
            $body = $match.Groups["body"].Value
            $teamId = Convert-ToNullableInt (Get-SetupValue -Text $body -Name "team")
            $team = if ($null -ne $teamId -and $teams.ContainsKey($teamId)) { $teams[$teamId] } else { $null }

            $ais += [pscustomobject]@{
                AiId = $aiId
                Name = Get-SetupValue -Text $body -Name "name"
                ShortName = Get-SetupValue -Text $body -Name "shortname"
                Version = Get-SetupValue -Text $body -Name "version"
                TeamId = $teamId
                AllyTeamId = if ($null -ne $team) { $team.AllyTeamId } else { $null }
                Side = if ($null -ne $team) { $team.Side } else { $null }
            }
        }

        $winningAllyTeams = @()
        if ($demoStreamSize -gt 0 -and $winningAllyTeamsSize -gt 0) {
            Skip-Bytes -Reader $reader -Count $demoStreamSize
            $winningAllyTeams = @($reader.ReadBytes($winningAllyTeamsSize) | ForEach-Object { [int] $_ })
            if ($winningAllyTeams.Count -ne $winningAllyTeamsSize) {
                throw "Unexpected end of winning ally-team data in $resolvedPath"
            }
        }

        $gameId = ($gameIdBytes | ForEach-Object { $_.ToString("x2") }) -join ""
        $startedUtc = [DateTimeOffset]::FromUnixTimeSeconds([long] $unixTime).UtcDateTime

        return [pscustomobject]@{
            File = [System.IO.Path]::GetFileName($resolvedPath)
            FullPath = $resolvedPath
            FormatVersion = $formatVersion
            HeaderSize = $headerSize
            EngineVersion = $engineVersion
            GameVersion = Get-SetupValue -Text $setupText -Name "gametype"
            Map = Get-SetupValue -Text $setupText -Name "mapname"
            GameId = $gameId
            StartedUtc = $startedUtc.ToString("o")
            GameTimeSeconds = $gameTime
            WallclockTimeSeconds = $wallclockTime
            EndedNormally = $demoStreamSize -gt 0
            WinningAllyTeams = $winningAllyTeams
            NumPlayersWithStats = $numPlayers
            NumTeamsWithStats = $numTeams
            PlayerStatSize = $playerStatSize
            PlayerStatElemSize = $playerStatElemSize
            TeamStatSize = $teamStatSize
            TeamStatElemSize = $teamStatElemSize
            TeamStatPeriodSeconds = $teamStatPeriod
            Players = $players
            AIs = $ais
        }
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $gzipStream) { $gzipStream.Dispose() }
        $fileStream.Dispose()
    }
}

$metadata = @($Path | ForEach-Object { Read-ReplayMetadata -ReplayPath $_ })

if ($AsJson) {
    $metadata | ConvertTo-Json -Depth 6
}
else {
    $metadata
}
