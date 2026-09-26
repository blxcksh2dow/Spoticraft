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
    # Add-Type tries to Assembly.LoadFrom each .winmd and fails before compilation.
    # CodeDOM passes WinRT metadata straight to the .NET Framework C# compiler.
    Add-Type -AssemblyName Microsoft.CSharp
    $compiler = New-Object Microsoft.CSharp.CSharpCodeProvider
    try {
        $options = New-Object System.CodeDom.Compiler.CompilerParameters
        $options.GenerateInMemory = $true
        foreach ($reference in $references) { $null = $options.ReferencedAssemblies.Add($reference) }
        $compiled = $compiler.CompileAssemblyFromSource($options, [string[]]@($source + "`n" + $ExtraTestSource))
        if ($compiled.Errors.HasErrors) {
            throw (($compiled.Errors | Where-Object { -not $_.IsWarning } | ForEach-Object { $_.ToString() }) -join "`n")
        }
        $null = $compiled.CompiledAssembly
    } finally { $compiler.Dispose() }
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
