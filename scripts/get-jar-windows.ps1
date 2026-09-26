# Obtains a local build toolchain, then builds the real mod. No prebuilt JAR is downloaded.
[CmdletBinding()]
param([switch]$OpenFolder)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$oldJavaHome = $env:JAVA_HOME
$oldPath = $env:PATH

function Test-Jdk25([string]$HomePath) {
    if (-not $HomePath) { return $false }
    $compiler = Join-Path $HomePath 'bin\javac.exe'
    $runtime = Join-Path $HomePath 'bin\java.exe'
    if (-not (Test-Path $compiler) -or -not (Test-Path $runtime)) { return $false }
    try {
        $version = (& $compiler -version 2>&1 | Out-String).Trim()
        return ($LASTEXITCODE -eq 0 -and $version -match '^javac 25(?:\.|\s|$)')
    } catch { return $false }
}

try {
    Write-Host 'Spoticraft 26.2 - creazione automatica del JAR' -ForegroundColor Green
    Write-Host 'Non scarica una mod precompilata: scarica gli strumenti, esegue test e build.'
    Write-Host 'Servono Internet e spazio per JDK, Gradle e Minecraft. Nessun upload su GitHub.'
    $tools = Join-Path $root '.tools'
    $localJdk = Join-Path $tools 'jdk-25'
    $jdk = $null
    if (Test-Jdk25 $env:JAVA_HOME) { $jdk = $env:JAVA_HOME }
    if (-not $jdk) {
        $javac = Get-Command javac.exe -ErrorAction SilentlyContinue
        if ($javac) {
            $candidate = Split-Path (Split-Path $javac.Source -Parent) -Parent
            if (Test-Jdk25 $candidate) { $jdk = $candidate }
        }
    }
    if (-not $jdk -and (Test-Jdk25 $localJdk)) { $jdk = $localJdk }
    if (-not $jdk) {
        $architecture = $env:PROCESSOR_ARCHITECTURE
        if ($env:PROCESSOR_ARCHITEW6432) { $architecture = $env:PROCESSOR_ARCHITEW6432 }
        if ($architecture -ne 'AMD64') {
            throw 'Download automatico disponibile per Windows x64. Su altri sistemi configura manualmente un JDK 25 in JAVA_HOME.'
        }
        New-Item -ItemType Directory -Force -Path $tools | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host '1/3 - Download JDK 25 portatile da Eclipse Adoptium (solo al primo avvio)...'
        $api = 'https://api.adoptium.net/v3/assets/latest/25/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'
        $assets = @(Invoke-RestMethod -Uri $api -TimeoutSec 60)
        if ($assets.Count -eq 0) { throw 'Adoptium non ha restituito un JDK 25 per Windows x64.' }
        $package = $assets[0].binary.package
        $url = [Uri]$package.link
        $expected = [string]$package.checksum
        if ($url.Scheme -ne 'https' -or $expected -notmatch '^[a-fA-F0-9]{64}$') {
            throw 'Metadati del download JDK non validi.'
        }
        $archive = Join-Path $tools 'jdk-25.zip'
        $staging = Join-Path $tools 'jdk-extract'
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $url.AbsoluteUri -OutFile $archive -TimeoutSec 900
            $actual = (Get-FileHash -Path $archive -Algorithm SHA256).Hash
            if ($actual -ne $expected) { throw 'Checksum SHA-256 JDK non valido. Download rifiutato.' }
            if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
            Expand-Archive -LiteralPath $archive -DestinationPath $staging
            $candidate = Get-ChildItem -LiteralPath $staging -Directory | Where-Object {
                Test-Path (Join-Path $_.FullName 'bin\javac.exe')
            } | Select-Object -First 1
            if (-not $candidate -or -not (Test-Jdk25 $candidate.FullName)) {
                throw 'Il pacchetto scaricato non contiene un JDK 25 utilizzabile.'
            }
            if (Test-Path $localJdk) { Remove-Item -Recurse -Force $localJdk }
            Move-Item -LiteralPath $candidate.FullName -Destination $localJdk
            $jdk = $localJdk
        } finally {
            if (Test-Path $archive) { Remove-Item -Force $archive }
            if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
        }
    } else { Write-Host "1/3 - Uso JDK 25: $jdk" }

    # Environment changes are limited to this process and its children.
    $env:JAVA_HOME = $jdk
    $env:PATH = (Join-Path $jdk 'bin') + ';' + $oldPath
    Write-Host '2/3 - Download dipendenze, test e compilazione (il primo avvio puo richiedere diversi minuti)...'
    & (Join-Path $PSScriptRoot 'build-windows.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Build non riuscita. Leggi gli errori precedenti.' }
    $jar = Join-Path $root 'download\spoticraft-26.2.jar'
    if (-not (Test-Path $jar) -or (Get-Item $jar).Length -eq 0) {
        throw 'La build non ha prodotto il JAR atteso.'
    }
    Write-Host "3/3 - JAR pronto: $jar" -ForegroundColor Green
    Write-Host "SHA-256: $((Get-FileHash -Path $jar -Algorithm SHA256).Hash)"
    Write-Host 'Installa il JAR con Fabric Loader e Fabric API per Minecraft 26.2.'
    if ($OpenFolder) {
        try { Start-Process explorer.exe -ArgumentList ('/select,"' + $jar + '"') }
        catch { Write-Warning 'JAR creato, ma impossibile aprire Esplora file. Apri la cartella download.' }
    }
} catch {
    Write-Host "ERRORE: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Nessun nuovo JAR pronto. Controlla connessione Internet e messaggi della build.'
    exit 1
} finally {
    $env:JAVA_HOME = $oldJavaHome
    $env:PATH = $oldPath
}
