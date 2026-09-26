$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
try {
    if (-not (Get-Command java -ErrorAction SilentlyContinue) -and -not $env:JAVA_HOME) {
        throw 'Installa un JDK 25 (non solo JRE), configura JAVA_HOME e riapri il terminale.'
    }
    & .\gradlew.bat --no-daemon clean downloadMod
    if ($LASTEXITCODE -ne 0) { throw "Compilazione fallita (codice $LASTEXITCODE). Nessun nuovo JAR prodotto." }
    Write-Host "Mod pronta: $(Join-Path (Get-Location) 'download\spoticraft-26.2.jar')" -ForegroundColor Green
} catch {
    Write-Error $_
    exit 1
}
