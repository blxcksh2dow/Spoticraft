# Development/build step only. This script is NEVER included in or launched by the mod.
param([switch]$RunTests)
$ErrorActionPreference = 'Stop'
try {
    $root = Split-Path $PSScriptRoot -Parent
    $output = Join-Path $root 'build\generated\bridge-resources\native'
    $testOutput = Join-Path $root 'build\native-tests'
    New-Item -ItemType Directory -Force -Path $output, $testOutput | Out-Null
    $compiler = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    if (-not (Test-Path $compiler)) { throw 'Windows .NET Framework C# compiler not found.' }
    $references = @('System.dll', 'System.Core.dll', 'System.Web.Extensions.dll')
    foreach ($name in @('System.Runtime', 'System.Runtime.InteropServices.WindowsRuntime', 'System.ObjectModel', 'System.Threading.Tasks')) {
        $assembly = [Reflection.Assembly]::LoadWithPartialName($name)
        if ($null -eq $assembly) { throw "Windows .NET Framework assembly missing: $name" }
        $references += $assembly.Location
    }
    $references += @(Get-ChildItem (Join-Path $env:SystemRoot 'System32\WinMetadata\*.winmd') | ForEach-Object { $_.FullName })
    $common = @('/nologo', '/target:exe', '/platform:anycpu', '/optimize+', '/debug-', '/utf8output')
    $common += @($references | ForEach-Object { "/reference:$_" })
    $sources = @(Get-ChildItem (Join-Path $root 'native\src\*.cs') | ForEach-Object { $_.FullName })
    $exe = Join-Path $output 'Spoticraft.Bridge.exe'
    & $compiler @common /main:Spoticraft.Native.Program "/out:$exe" @sources
    if ($LASTEXITCODE -ne 0) { throw "Native bridge compilation failed ($LASTEXITCODE)." }
    $hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $output 'Spoticraft.Bridge.sha256'), $hash, [Text.Encoding]::ASCII)
    Write-Host "Bridge built: $exe (SHA-256 $hash)"
    if ($RunTests) {
        $tests = @(Get-ChildItem (Join-Path $root 'native\tests\*.cs') | ForEach-Object { $_.FullName })
        $testExe = Join-Path $testOutput 'Spoticraft.Bridge.Tests.exe'
        & $compiler @common /main:Spoticraft.Tests.TestProgram "/out:$testExe" @sources @tests
        if ($LASTEXITCODE -ne 0) { throw "Native tests compilation failed ($LASTEXITCODE)." }
        $testLog = & $testExe 2>&1 | Out-String
        $testCode = $LASTEXITCODE
        Write-Host $testLog
        if ($testCode -ne 0) { throw "Native regression tests failed ($testCode): $testLog" }
    }
} catch {
    $message = ($_ | Out-String).Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    Write-Host "::error title=Native bridge build failed::$message"
    exit 1
}
