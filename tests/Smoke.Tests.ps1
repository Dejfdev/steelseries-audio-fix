# Read-only smoke checks. Run with either Windows PowerShell 5.1 or PowerShell 7.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'src\SteelSeriesFix.ps1'
$source = Join-Path $root 'src\CoreAudio.cs'

if (-not (Test-Path -LiteralPath $script)) { throw "Missing script: $script" }
if (-not (Test-Path -LiteralPath $source)) { throw "Missing C# source: $source" }

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
Write-Host 'PASS: PowerShell syntax'

# Compilation checks interop declarations without creating COM objects or changing audio.
Add-Type -Path $source -ErrorAction Stop
Write-Host 'PASS: Core Audio interop compiles'
$assembly = [SteelFix.Audio].Assembly
$collection = $assembly.GetType('SteelFix.IMMDeviceCollection', $true)
if ($collection.GUID -ne [guid]'0BD7A1BE-7A1A-44DB-8397-CC5392387B5E') { throw 'Incorrect IMMDeviceCollection IID' }
$variant = $assembly.GetType('SteelFix.PropVariant', $true)
if ([IntPtr]::Size -eq 8 -and [Runtime.InteropServices.Marshal]::SizeOf([Activator]::CreateInstance($variant)) -lt 24) { throw 'PROPVARIANT allocation is too small on 64-bit Windows' }
$volume = $assembly.GetType('SteelFix.IAudioEndpointVolume', $true)
foreach ($name in @('SetMasterVolumeLevelScalar', 'SetMute')) {
    $param = $volume.GetMethod($name).GetParameters()[-1].ParameterType
    if ($param -ne [IntPtr] -and -not ($param.IsByRef -and $param.GetElementType() -eq [guid])) { throw "$name must pass the event GUID by pointer" }
}
Write-Host 'PASS: interop IID, struct size and pointer signatures'

# Noninteractive diagnosis must terminate even when the CI machine has no sound device.
# It runs in a separate process to catch accidental prompts and process exit codes.
$hostExe = (Get-Process -Id $PID).Path
$stdout = Join-Path ([IO.Path]::GetTempPath()) ("audiofix-out-" + [guid]::NewGuid() + '.txt')
$stderr = Join-Path ([IO.Path]::GetTempPath()) ("audiofix-err-" + [guid]::NewGuid() + '.txt')
try {
    $process = Start-Process -FilePath $hostExe -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script + '"'), '-DiagnoseOnly') -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # Keep the process handle open so Windows PowerShell 5.1 can retrieve ExitCode.
    $null = $process.Handle
    if (-not $process.WaitForExit(60000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'Diagnosis did not finish within 60 seconds; check for an interactive prompt.'
    }
    $out = Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue
    $err = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
    if ($process.ExitCode -ne 0) { throw "Diagnosis exited $($process.ExitCode).`n$out`n$err" }
    if ([string]::IsNullOrWhiteSpace($out)) { throw 'Diagnosis returned no output.' }
    Write-Host 'PASS: noninteractive diagnosis completed'
} finally {
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
}
