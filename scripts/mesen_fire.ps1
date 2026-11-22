# EGRET II mini: five configurable buttons -> global keyboard input.
# Windows PowerShell 5.1 / PowerShell 7. Keep all companion files together.
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$CaptureInterface = 'USBPcap1',
    [string]$TSharkPath
)
$ErrorActionPreference = 'Stop'
$capture = $null
try {
    # With Windows PowerShell -File, PSScriptRoot can be empty while param()
    # default expressions are evaluated. Resolve paths only after binding.
    if (-not $PSBoundParameters.ContainsKey('ConfigPath')) {
        $ConfigPath = Join-Path $PSScriptRoot 'buttons.json'
    }
    if (-not $PSBoundParameters.ContainsKey('TSharkPath')) {
        $TSharkPath = Join-Path $env:ProgramFiles 'Wireshark\tshark.exe'
    }
    if (-not (Test-Path -LiteralPath $TSharkPath -PathType Leaf)) {
        throw "TShark was not found: $TSharkPath"
    }
    if ($CaptureInterface -notmatch '^USBPcap[1-9][0-9]*$') {
        throw 'CaptureInterface must be USBPcap1, USBPcap2, etc.'
    }
    if (-not ('EgretButtons.Capture' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'EgretButtons.cs')
    }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $config -or $config -isnot [pscustomobject]) {
        throw 'buttons.json must contain a JSON object with the five button names.'
    }
    $names = @('right', 'left', 'topLeft', 'topRight', 'topBottom')
    $properties = @($config.PSObject.Properties.Name)
    foreach ($property in $properties) {
        if ($names -cnotcontains $property) { throw "Unknown button name: $property" }
    }
    $keys = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    foreach ($name in $names) {
        if ($properties -cnotcontains $name) { throw "Missing button name: $name" }
        $value = $config.$name
        if ($null -ne $value -and $value -isnot [string]) {
            throw "The key for '$name' must be a string or null."
        }
        if ($null -eq $value) {
            # PowerShell otherwise coerces a null string argument to an empty string.
            $keys.Add($name, [NullString]::Value)
        } else {
            [void][EgretButtons.KeyNames]::Resolve($value)
            $keys.Add($name, $value)
        }
    }
    Write-Host 'EGRET II mini -> All applications: configurable buttons' -ForegroundColor Cyan
    foreach ($name in $names) {
        $label = if ([string]::IsNullOrEmpty($keys[$name])) { '(disabled)' } else { $keys[$name] }
        Write-Host ('  {0,-10} -> {1}' -f $name, $label)
    }
    Write-Host 'Mesen: map Fire to Space and player 1 Start to Enter for the defaults.'
    Write-Host 'Close any active Wireshark capture. Unplug the TAITO controller.' -ForegroundColor Yellow
    [void](Read-Host 'Press Enter when unplugged to start monitoring')
    $capture = New-Object EgretButtons.Capture
    $capture.Start($TSharkPath, $CaptureInterface, $keys)
    Write-Host "Starting $CaptureInterface monitoring. Plug the TAITO controller in now." -ForegroundColor Green
    Write-Host 'Input target: ALL APPLICATIONS (the foreground app receives keys).'
    Write-Host 'Ctrl+C here stops capture and releases keys.'
    while ($capture.IsRunning) {
        foreach ($message in $capture.DrainMessages()) { Write-Host $message }
        Start-Sleep -Milliseconds 50
    }
    foreach ($message in $capture.DrainMessages()) { Write-Host $message }
    if ($capture.ErrorMessage) { throw $capture.ErrorMessage }
} catch {
    Write-Host ('Error: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($null -ne $capture) { $capture.Stop() }
}
