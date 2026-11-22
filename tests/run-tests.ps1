# Offline tests: no controller, USB capture, or keyboard input required.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\scripts\EgretButtons.cs'
Add-Type -Path @($source, (Join-Path $PSScriptRoot 'ButtonTests.cs'))
$count = [ButtonTests]::Run()
Write-Host "PASS: $count state/decoder/routing assertions."

# Validate the actual PS entry point's JSON loader without starting its capture code.
$entry = Join-Path $PSScriptRoot '..\scripts\mesen_fire.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($entry, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$loaderStart = $ast.Extent.Text.IndexOf('    $config = Get-Content')
$loaderEnd = $ast.Extent.Text.IndexOf("    Write-Host 'EGRET II mini")
if ($loaderStart -lt 0 -or $loaderEnd -le $loaderStart) { throw 'Cannot locate config loader.' }
$loader = [scriptblock]::Create($ast.Extent.Text.Substring($loaderStart, $loaderEnd - $loaderStart))
$ConfigPath = Join-Path $PSScriptRoot '..\scripts\buttons.json'
. $loader
$loaded = New-Object EgretButtons.ButtonState -ArgumentList $keys
if ($loaded.Report(12).Count -ne 0) { throw 'JSON null must disable the two upper buttons.' }
$changes = $loaded.Report(3)
if ($changes.Count -ne 1 -or $changes[0].Key -ne 32 -or -not $changes[0].Down) { throw 'JSON Space mappings were not loaded.' }
Write-Host 'PASS: shipped JSON and PowerShell null-string conversion.'

$temp = Join-Path ([IO.Path]::GetTempPath()) ('egret-buttons-tests-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
$launchDirectory = Join-Path $temp ('folder with spaces ' + [char]0x65E5 + [char]0x672C)
$companionFiles = @('START_FIRE.cmd', 'mesen_fire.ps1', 'EgretButtons.cs', 'buttons.json', 'mesen_spinner.ahk')
try {
    foreach ($bad in @(
        '{"right":"Spcae","left":"Space","topLeft":null,"topRight":null,"topBottom":"Enter"}',
        '{"right":123,"left":"Space","topLeft":null,"topRight":null,"topBottom":"Enter"}',
        '{"right":"Space"}',
        '{"Right":"Space","left":"Space","topLeft":null,"topRight":null,"topBottom":"Enter"}',
        '{"right":"Space","left":"Space","topLeft":null,"topRight":null,"topBottom":"Enter","typo":null}',
        '[]', 'null', '{bad'
    )) {
        $ConfigPath = Join-Path $temp 'bad.json'
        [IO.File]::WriteAllText($ConfigPath, $bad)
        $rejected = $false
        try { . $loader } catch { $rejected = $true }
        if (-not $rejected) { throw "Accepted invalid config: $bad" }
    }
    Write-Host 'PASS: eight invalid config cases.'

    # A local fixture tests the subprocess, stderr, EOF and stop paths.
    # All bindings are null, so it cannot generate any keyboard input.
    $fixturePath = Join-Path $temp 'EgretCaptureFixture.exe'
    $fixtureSource = @'
using System;
using System.Threading;
public static class EgretCaptureFixture {
    public static void Main(string[] args) {
        Console.Error.WriteLine("Capturing on 'USBPcap1'");
        Console.WriteLine("1\t17\t0x0ae4\t0x0701\t");
        Console.Out.Flush();
        if (args.Length > 1 && args[1] == "USBPcap2") return;
        Thread.Sleep(30000);
    }
}
'@
    # Console EXE compilation is available in Windows PowerShell 5.1.
    if ($PSVersionTable.PSEdition -ne 'Core') {
        Add-Type -TypeDefinition $fixtureSource -OutputAssembly $fixturePath -OutputType ConsoleApplication
        $disabled = New-Object 'System.Collections.Generic.Dictionary[string,string]'
        foreach ($name in [EgretButtons.ButtonState]::Names) { $disabled.Add($name, [NullString]::Value) }
        foreach ($interface in @('USBPcap1', 'USBPcap2')) {
            $capture = New-Object EgretButtons.Capture
            try {
                $capture.Start($fixturePath, $interface, $disabled)
                $deadline = [DateTime]::UtcNow.AddSeconds(5)
                $output = @()
                do {
                    Start-Sleep -Milliseconds 20
                    $output += $capture.DrainMessages()
                } while ($capture.IsRunning -and -not ($output -match 'TAITO detected') -and [DateTime]::UtcNow -lt $deadline)
                if ($interface -eq 'USBPcap1') {
                    if (-not ($output -match 'TAITO detected')) { throw ('Fixture was not detected. ' + $capture.ErrorMessage + ' ' + ($output -join '; ')) }
                    $capture.Stop()
                    if ($capture.ErrorMessage) { throw $capture.ErrorMessage }
                } else {
                    while ($capture.IsRunning -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
                    if (-not $capture.ErrorMessage -or $capture.IsRunning) { throw 'Unexpected EOF did not stop capture.' }
                }
                if ($capture.IsRunning) { throw 'Capture did not stop.' }
            } finally { $capture.Stop() }
        }
        Write-Host 'PASS: subprocess stderr, descriptor detection, clean stop, unexpected EOF.'

        # Exercise the real entry point, including param() defaults. The previous
        # loader-only test missed PSScriptRoot being empty in -File parameter defaults.
        # The fixture emits a descriptor but no button reports: no USB/keyboard input.
        [void][IO.Directory]::CreateDirectory($launchDirectory)
        foreach ($file in $companionFiles) {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('..\scripts\' + $file)) -Destination $launchDirectory
        }
        foreach ($mode in @('File', 'Cmd')) {
            $info = New-Object System.Diagnostics.ProcessStartInfo
            if ($mode -eq 'File') {
                $info.FileName = Join-Path $PSHOME 'powershell.exe'
                $info.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -TSharkPath "{1}" -CaptureInterface USBPcap2' -f (Join-Path $launchDirectory 'mesen_fire.ps1'), $fixturePath
            } else {
                $info.FileName = $env:ComSpec
                $info.Arguments = '/d /c ""{0}" -TSharkPath "{1}" -CaptureInterface USBPcap2"' -f (Join-Path $launchDirectory 'START_FIRE.cmd'), $fixturePath
            }
            $info.WorkingDirectory = $temp
            $info.UseShellExecute = $false
            $info.CreateNoWindow = $true
            $info.RedirectStandardInput = $true
            $info.RedirectStandardOutput = $true
            $info.RedirectStandardError = $true
            $launched = New-Object System.Diagnostics.Process
            $launched.StartInfo = $info
            try {
                [void]$launched.Start()
                $stdoutTask = $launched.StandardOutput.ReadToEndAsync()
                $stderrTask = $launched.StandardError.ReadToEndAsync()
                $launched.StandardInput.WriteLine('')
                $launched.StandardInput.WriteLine('')
                $launched.StandardInput.Close()
                if (-not $launched.WaitForExit(15000)) {
                    $launched.Kill()
                    throw "$mode launch timed out."
                }
                $stdout = $stdoutTask.GetAwaiter().GetResult()
                $stderr = $stderrTask.GetAwaiter().GetResult()
                foreach ($expected in @('right\s+-> Space', 'left\s+-> Space', 'topLeft\s+-> \(disabled\)', 'topRight\s+-> \(disabled\)', 'topBottom\s+-> Enter', 'Input target: ALL APPLICATIONS', 'Starting USBPcap2 monitoring', 'TAITO detected', 'TShark capture ended')) {
                    if ($stdout -notmatch $expected) { throw "$mode launch missing '$expected': $stdout $stderr" }
                }
                if ($stderr -or $stdout -match 'Join-Path|Key down:|Key up:') { throw "$mode launch unexpected output: $stdout $stderr" }
                if ($mode -eq 'File' -and $launched.ExitCode -ne 1) { throw 'Expected exit code 1 after fixture EOF.' }
            } finally {
                $launched.Dispose()
            }
        }
        Write-Host 'PASS: actual PowerShell -File and CMD launch, default JSON, Unicode/spaced paths, alternate working directory.'
    } else {
        Write-Host 'SKIP: console EXE fixture on PowerShell Core; run with powershell.exe for this check.'
    }
} finally {
    # Only remove known fixture files within this uniquely created test directory.
    if (Test-Path -LiteralPath $launchDirectory) {
        foreach ($file in $companionFiles) {
            $candidate = Join-Path $launchDirectory $file
            if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Force }
        }
        Remove-Item -LiteralPath $launchDirectory
    }
    foreach ($file in @('bad.json', 'EgretCaptureFixture.exe')) {
        $candidate = Join-Path $temp $file
        if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Force }
    }
    Remove-Item -LiteralPath $temp
}
