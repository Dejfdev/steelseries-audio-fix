[CmdletBinding()]
param([switch]$DiagnoseOnly)
$ErrorActionPreference = 'Stop'
try {
    if ($env:OS -ne 'Windows_NT') { throw 'Ten program wymaga systemu Windows 11.' }
    Add-Type -Path (Join-Path $PSScriptRoot 'CoreAudio.cs')
} catch { Write-Host "Nie można uruchomić diagnostyki: $_" -ForegroundColor Red; exit 1 }

$script:backupDir = Join-Path $env:LOCALAPPDATA 'SteelSeriesFix\Backups'
$script:roles = @('Console', 'Multimedia', 'Communications')
function Get-Outputs { @([SteelFix.Audio]::List([SteelFix.DataFlow]::Render)) }
function Get-Defaults {
    $result = @{}
    foreach ($role in $script:roles) { $result[$role] = [SteelFix.Audio]::DefaultId([SteelFix.DataFlow]::Render, [SteelFix.Role]::$role) }
    return $result
}
function Get-ServicesInfo {
    foreach ($name in @('AudioEndpointBuilder', 'Audiosrv')) {
        try { Get-CimInstance Win32_Service -Filter "Name='$name'" | Select-Object Name, State, StartMode }
        catch { [pscustomobject]@{ Name=$name; State='UNKNOWN'; StartMode='UNKNOWN' } }
    }
}
function Show-Diagnosis {
    Write-Host "`n=== Diagnoza (bez zmian) ===" -ForegroundColor Cyan
    try {
        $outputs = Get-Outputs; $defaults = Get-Defaults
        if ($outputs.Count -eq 0) { Write-Host 'Brak aktywnych wyjść audio w systemie.' }
        foreach ($device in $outputs) {
            $roles = @($script:roles | Where-Object { $defaults[$_] -eq $device.Id }) -join ', '
            Write-Host ("  {0} | głośność {1}% | wyciszony: {2} | domyślny: {3}" -f $device.Name, [math]::Round($device.Volume*100), $device.Muted, $roles)
        }
        foreach ($role in $script:roles) { if (-not $defaults[$role]) { Write-Host "  Brak domyślnego wyjścia dla roli: $role" } }
        Write-Host "`nUsługi Windows:"
        Get-ServicesInfo | Format-Table -AutoSize | Out-Host
        $gg = Get-Process -Name 'SteelSeriesGG','SteelSeriesGGClient','SteelSeriesEngine' -ErrorAction SilentlyContinue
        if ($gg) { Write-Host 'SteelSeries GG: wykryto proces.' } else { Write-Host 'SteelSeries GG: nie wykryto procesu (nazwa procesu może się różnić).' }
        try {
            $pnp = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.FriendlyName -match 'SteelSeries|Arctis|Sonar' } | Select-Object FriendlyName, Class, Status)
            if ($pnp.Count) { Write-Host "`nWykryte urządzenia SteelSeries/Sonar:"; $pnp | Format-Table -AutoSize | Out-Host }
            else { Write-Host 'Nie znaleziono podłączonego urządzenia o nazwie SteelSeries, Arctis lub Sonar.' }
        } catch { Write-Host "Nie można odczytać urządzeń PnP: $_" }
        Write-Host "`nSonar: sprawdź w GG > Sonar > Mixer, czy kanał wskazuje faktyczne słuchawki."
        Write-Host 'Program nie potrafi potwierdzić, czy dźwięk jest słyszalny ani odczytać routingu Sonar.'
        return $true
    } catch { Write-Host "Błąd odczytu Windows Core Audio: $_" -ForegroundColor Red; Write-Host "Stan usług Windows:"; Get-ServicesInfo | Format-Table -AutoSize | Out-Host; $gg = Get-Process -Name 'SteelSeriesGG','SteelSeriesGGClient','SteelSeriesEngine' -ErrorAction SilentlyContinue; if ($gg) { Write-Host 'SteelSeries GG: wykryto proces.' } else { Write-Host 'SteelSeries GG: nie wykryto procesu (nazwa procesu może się różnić).' }; return $false }
}
function Save-Snapshot([string]$reason, [switch]$ServiceOnly) {
    $outputs = @(); $defaults = $null
    if (-not $ServiceOnly) { $outputs = Get-Outputs; $defaults = Get-Defaults }
    $snapshot = [ordered]@{
        Version = 1; Created = (Get-Date).ToString('o'); Reason = $reason
        Defaults = $defaults
        Outputs = @($outputs | Select-Object Id, Name, Flow, Volume, Muted)
        Services = @(Get-ServicesInfo)
    }
    New-Item -ItemType Directory -Force -Path $script:backupDir | Out-Null
    $path = Join-Path $script:backupDir ("{0}-{1}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N'))
    # CreateNew prevents overwriting existing recovery information.
    $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false))); try { $writer.Write(($snapshot | ConvertTo-Json -Depth 6)) } finally { $writer.Dispose() } } finally { $stream.Dispose() }
    Write-Host "Kopia stanu: $path" -ForegroundColor DarkGray
    return $path
}
function Confirm-Action([string]$message) { (Read-Host "$message [t/N]") -match '^[tT]$' }
function Select-Output {
    $devices = @(Get-Outputs)
    if (-not $devices.Count) { Write-Host 'Brak aktywnych wyjść. Podłącz słuchawki i spróbuj ponownie.'; return $null }
    for ($i=0; $i -lt $devices.Count; $i++) { Write-Host ("{0}. {1} ({2}%, wyciszony: {3})" -f ($i+1), $devices[$i].Name, [math]::Round($devices[$i].Volume*100), $devices[$i].Muted) }
    $answer = Read-Host 'Numer wyjścia (Enter = anuluj)'; $n = 0
    if (-not [int]::TryParse($answer, [ref]$n) -or $n -lt 1 -or $n -gt $devices.Count) { Write-Host 'Anulowano.'; return $null }
    return $devices[$n-1]
}
function Set-OutputDefault {
    $device = Select-Output; if (-not $device) { return }
    Write-Host 'Zmiana dotyczy ról zwykłej i multimediów. Rola komunikacji pozostanie bez zmian.'
    Write-Host 'Używany jest nieudokumentowany interfejs Windows; może nie działać w przyszłych wersjach.'
    if (-not (Confirm-Action "Ustawić wyjście '$($device.Name)'?")) { return }
    $null = Save-Snapshot 'przed zmianą domyślnego wyjścia'
    $failures = 0
    foreach ($role in @('Console', 'Multimedia')) {
        try { [SteelFix.Audio]::SetDefault($device.Id, [SteelFix.Role]::$role); Write-Host "Ustawiono: $role" }
        catch { $failures++; Write-Host "Błąd dla $role`: $_" -ForegroundColor Red }
    }
    if ($failures) { Write-Host 'Zmiana częściowa. Wybierz przywracanie kopii, jeśli chcesz cofnąć zmiany.' -ForegroundColor Yellow }
    Write-Host 'Jeśli używasz Sonar, wybierz Sonar Gaming w Windows i sprawdź fizyczne słuchawki w mikserze Sonar.'
}
function Set-OutputVolume {
    $device = Select-Output; if (-not $device) { return }
    Write-Host 'Opcjonalna zmiana głośności i wyłączenie wyciszenia tylko dla wybranego wyjścia.'
    $text = Read-Host 'Podaj poziom 0–35% (Enter = anuluj)'; $n=0
    if (-not [int]::TryParse($text, [ref]$n) -or $n -lt 0 -or $n -gt 35) { Write-Host 'Anulowano: podaj liczbę od 0 do 35.'; return }
    if (-not (Confirm-Action "Ustawić '$($device.Name)' na $n% i wyłączyć wyciszenie?")) { return }
    $null = Save-Snapshot 'przed zmianą głośności wyjścia'
    [SteelFix.Audio]::SetVolume($device.Id, [single]($n/100.0), $false)
    Write-Host 'Zmieniono ustawienia wyjścia. Sprawdź dźwięk i ostrożnie dopasuj poziom.'
}
function Start-AudioServices {
    $services = @(Get-Service -Name AudioEndpointBuilder,Audiosrv)
    $stopped = @($services | Where-Object Status -eq 'Stopped')
    if (-not $stopped.Count) { Write-Host 'Żadna z dwóch usług nie jest zatrzymana. Nie wykonano zmian.'; return }
    Write-Host ('Zatrzymane usługi: ' + (($stopped | Select-Object -ExpandProperty Name) -join ', '))
    Write-Host 'Uruchomienie może wymagać administratora. Typ uruchamiania nie zostanie zmieniony.'
    if (-not (Confirm-Action 'Spróbować uruchomić zatrzymane usługi?')) { return }
    $null = Save-Snapshot 'przed uruchomieniem usług' -ServiceOnly
    foreach ($name in @('AudioEndpointBuilder','Audiosrv')) {
        if (@($stopped | Where-Object Name -eq $name).Count) {
            try { Start-Service -Name $name -ErrorAction Stop; Write-Host "Uruchomiono $name." }
            catch { Write-Host "Nie uruchomiono $name`: $_. Spróbuj uruchomić program jako administrator." -ForegroundColor Red }
        }
    }
    Write-Host 'Przywracanie w tym programie nie zatrzymuje usług; wcześniejszy stan znajduje się w kopii.'
}
function Restore-Snapshot {
    if (-not (Test-Path $script:backupDir)) { Write-Host 'Brak kopii.'; return }
    $files = @(Get-ChildItem -LiteralPath $script:backupDir -Filter '*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 20)
    if (-not $files.Count) { Write-Host 'Brak kopii.'; return }
    for ($i=0; $i -lt $files.Count; $i++) { Write-Host ("{0}. {1}" -f ($i+1), $files[$i].Name) }
    $choice = Read-Host 'Numer kopii (Enter = anuluj)'; $n=0
    if (-not [int]::TryParse($choice, [ref]$n) -or $n -lt 1 -or $n -gt $files.Count) { Write-Host 'Anulowano.'; return }
    $snapshot = Get-Content -Raw -LiteralPath $files[$n-1].FullName | ConvertFrom-Json
    if ($snapshot.Version -ne 1 -or -not $snapshot.Defaults -or $null -eq $snapshot.Outputs) { throw 'Ta kopia nie zawiera ustawień wyjść (może zawierać tylko stan usług); wybierz inną.' }
    Write-Host "Kopia: $($snapshot.Created), powód: $($snapshot.Reason)"
    Write-Host 'Przywrócone zostaną domyślne wyjścia oraz poziomy i wyciszenie aktywnych wyjść zapisanych w kopii.'
    Write-Host 'Może to zwiększyć głośność do poprzedniego poziomu. Stan usług nie jest przywracany.' -ForegroundColor Yellow
    if (-not (Confirm-Action 'Przywrócić tę kopię?')) { return }
    $null = Save-Snapshot 'przed przywróceniem kopii'
    $active = @(Get-Outputs); $failures=0
    foreach ($role in $script:roles) {
        $id = $snapshot.Defaults.$role
        if (-not $id) { Write-Host "Pominięto $role`: kopia nie miała domyślnego wyjścia."; continue }
        if (-not @($active | Where-Object Id -eq $id).Count) { $failures++; Write-Host "Pominięto $role`: urządzenie nie jest aktywne."; continue }
        try { [SteelFix.Audio]::SetDefault($id, [SteelFix.Role]::$role); Write-Host "Przywrócono domyślne: $role" } catch { $failures++; Write-Host "Błąd $role`: $_" -ForegroundColor Red }
    }
    foreach ($saved in @($snapshot.Outputs)) {
        if (-not @($active | Where-Object Id -eq $saved.Id).Count) { $failures++; Write-Host "Pominięto nieaktywne wyjście: $($saved.Name)"; continue }
        try { [SteelFix.Audio]::SetVolume($saved.Id, [single]$saved.Volume, [bool]$saved.Muted); Write-Host "Przywrócono głośność: $($saved.Name)" } catch { $failures++; Write-Host "Błąd głośności $($saved.Name): $_" -ForegroundColor Red }
    }
    if ($failures) { Write-Host "Przywrócenie częściowe: $failures pominięć lub błędów." -ForegroundColor Yellow } else { Write-Host 'Przywrócono dostępne ustawienia wyjść.' }
}
if ($DiagnoseOnly) { if (Show-Diagnosis) { exit 0 } else { exit 1 } }
Write-Host 'SteelSeries Audio Fix — Windows 11' -ForegroundColor Cyan
Write-Host 'Diagnoza nie zmienia ustawień. Każda naprawa wymaga osobnego potwierdzenia.'
$null = Show-Diagnosis
while ($true) {
    Write-Host "`n1. Ponów diagnozę`n2. Wybierz domyślne wyjście Windows`n3. Ustaw głośność wybranego wyjścia`n4. Uruchom zatrzymane usługi audio`n5. Przywróć kopię ustawień wyjść`n6. Otwórz ustawienia dźwięku Windows`n0. Zakończ"
    $action = Read-Host 'Wybór'
    try {
        switch ($action) {
            '1' { $null = Show-Diagnosis }
            '2' { Set-OutputDefault }
            '3' { Set-OutputVolume }
            '4' { Start-AudioServices }
            '5' { Restore-Snapshot }
            '6' { Start-Process 'ms-settings:sound' }
            '0' { exit 0 }
            default { Write-Host 'Wybierz jedną z pozycji menu.' }
        }
    } catch { Write-Host "Operacja nie powiodła się: $_" -ForegroundColor Red }
}
