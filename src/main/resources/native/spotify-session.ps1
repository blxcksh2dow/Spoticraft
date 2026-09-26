# Windows PowerShell 5.1: only bootstraps the typed C# WinRT reader and writes JSON.
# Native WinRT objects must not be passed through PowerShell's COM adapter.
param([switch]$LibraryOnly)
$ErrorActionPreference = 'Stop'

function Initialize-SpoticraftBridge([string]$ExtraTestSource = '') {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $runtime = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $references = @('System.dll', 'System.Core.dll', 'System.Runtime.WindowsRuntime.dll')
    foreach ($facade in @('System.Runtime.dll', 'System.Runtime.InteropServices.WindowsRuntime.dll', 'System.ObjectModel.dll', 'System.Threading.Tasks.dll')) {
        $references += Join-Path $runtime "Facades\$facade"
    }
    $references += @(Get-ChildItem (Join-Path $env:SystemRoot 'System32\WinMetadata\*.winmd') | ForEach-Object { $_.FullName })
    $source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SpotifyBridge.cs'))
    Add-Type -TypeDefinition ($source + "`n" + $ExtraTestSource) -ReferencedAssemblies $references -Language CSharp
}
function Emit($value) {
    [Console]::WriteLine(($value | ConvertTo-Json -Compress -Depth 5))
    [Console]::Out.Flush()
}
if ($LibraryOnly) { return }
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
    Initialize-SpoticraftBridge
    $bridge = New-Object Spoticraft.Native.Bridge
    while ($true) {
        Emit ($bridge.Poll())
        Start-Sleep -Milliseconds 1000
    }
} catch {
    $errorCause = $_.Exception.GetBaseException()
    Emit @{ available = $false; status = 'Bridge Windows: errore initialization (vedi latest.log)'
        diagnostics = @(@{ stage = 'initialization'; type = $errorCause.GetType().FullName
            hresult = $errorCause.HResult; message = $errorCause.Message }) }
    exit 1
}
