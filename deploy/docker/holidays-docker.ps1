[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ComposeArgs
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\\..')).Path
Set-Location $RepoRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI was not found. Install and start Docker Desktop, then reopen PowerShell.'
}
$null = & docker compose version 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose v2 is unavailable. Update Docker Desktop and check: docker compose version'
}
$null = & docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'The Docker engine is not running. Start Docker Desktop and wait until it reports that the engine is running.'
}

$EnvFile = Join-Path $RepoRoot '.env.docker'
$ExampleFile = Join-Path $RepoRoot '.env.docker.example'
if (-not (Test-Path $EnvFile)) {
    if (-not (Test-Path $ExampleFile)) {
        throw '.env.docker.example is missing. Pull the latest Holidays repository.'
    }

    $Bytes = New-Object byte[] 32
    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $Rng.GetBytes($Bytes)
        $PostgresPassword = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
        $Rng.GetBytes($Bytes)
        $GatewayPassword = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
        $Rng.GetBytes($Bytes)
        $AccommodationPassword = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
        $Rng.GetBytes($Bytes)
        $BookingPassword = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
        $Rng.GetBytes($Bytes)
        $PaymentPassword = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
        $Rng.GetBytes($Bytes)
        $JwtSecret = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
        $Rng.GetBytes($Bytes)
        $InternalToken = [BitConverter]::ToString($Bytes).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $Rng.Dispose()
    }

    $Content = Get-Content -Raw $ExampleFile
    $Content = $Content.Replace('POSTGRES_PASSWORD=REPLACE_WITH_RANDOM_HEX', "POSTGRES_PASSWORD=$PostgresPassword")
    $Content = $Content.Replace('GATEWAY_DB_PASSWORD=REPLACE_WITH_RANDOM_HEX', "GATEWAY_DB_PASSWORD=$GatewayPassword")
    $Content = $Content.Replace('ACCOMMODATION_DB_PASSWORD=REPLACE_WITH_RANDOM_HEX', "ACCOMMODATION_DB_PASSWORD=$AccommodationPassword")
    $Content = $Content.Replace('BOOKING_DB_PASSWORD=REPLACE_WITH_RANDOM_HEX', "BOOKING_DB_PASSWORD=$BookingPassword")
    $Content = $Content.Replace('PAYMENT_DB_PASSWORD=REPLACE_WITH_RANDOM_HEX', "PAYMENT_DB_PASSWORD=$PaymentPassword")
    $Content = $Content.Replace('JWT_SECRET=REPLACE_WITH_AT_LEAST_64_RANDOM_HEX_CHARACTERS', "JWT_SECRET=$JwtSecret")
    $Content = $Content.Replace('INTERNAL_SERVICE_TOKEN=REPLACE_WITH_A_DIFFERENT_HEX_SECRET', "INTERNAL_SERVICE_TOKEN=$InternalToken")
    $Content = $Content.Replace('INTERNAL_SERVICE_TOKEN=REPLACE_WITH_A_DIFFERENT_RANDOM_HEX_SECRET', "INTERNAL_SERVICE_TOKEN=$InternalToken")
    Set-Content -Path $EnvFile -Value $Content -Encoding ASCII
    Write-Host 'Created .env.docker with unique local secrets. It is excluded from Git.'
}

if (-not $ComposeArgs -or $ComposeArgs.Count -eq 0) {
    $ComposeArgs = @('up', '-d', '--build')
}
& docker compose --env-file .env.docker @ComposeArgs
exit $LASTEXITCODE
