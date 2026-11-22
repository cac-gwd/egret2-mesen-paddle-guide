# EGRET II mini paddle fire-button proof of concept for Mesen 2
# Requirements: Windows, Wireshark (TShark), USBPcap
# Tested protocol values are based on the user's capture: VID 0AE4, PID 0701.

# Windows PowerShell 5.1 treats native stderr status text as a terminating error under 'Stop'.
# TShark normally writes "Capturing on 'USBPcap1'" to stderr, so keep this as 'Continue'.
$ErrorActionPreference = 'Continue'
$tshark = Join-Path ${env:ProgramFiles} 'Wireshark\tshark.exe'
if (-not (Test-Path $tshark)) {
    Write-Host 'TShark was not found at:' -ForegroundColor Red
    Write-Host $tshark
    Write-Host 'Check that the TShark component is installed with Wireshark.'
    Read-Host 'Press Enter to exit'
    exit 1
}

Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
public static class EgretFireKey {
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    public static bool IsMesenActive() {
        uint pid;
        GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        if (pid == 0) return false;
        try {
            string name = Process.GetProcessById((int)pid).ProcessName;
            return name.IndexOf("mesen", StringComparison.OrdinalIgnoreCase) >= 0;
        } catch { return false; }
    }
    public static void TapSpace() {
        keybd_event(0x20, 0, 0, UIntPtr.Zero);
        Thread.Sleep(65);
        keybd_event(0x20, 0, 2, UIntPtr.Zero);
    }
}
'@

# New USB attachment is required to learn the transient USB bus/device address.
$script:targetBus = -1
$script:targetDevice = -1
$script:wasPressed = $false
$filter = '(usb.idVendor == 0x0ae4 && usb.idProduct == 0x0701) || usbhid.data'

Write-Host ''
Write-Host 'EGRET II mini -> Mesen Fire (Space) [experimental]' -ForegroundColor Cyan
Write-Host 'Close/stay out of an active Wireshark capture first.'
Write-Host 'Please unplug the TAITO paddle controller now.' -ForegroundColor Yellow
Read-Host 'Press Enter when unplugged to start monitoring'
Write-Host 'Starting USBPcap1 monitoring. Plug the TAITO paddle back in now.' -ForegroundColor Green
Write-Host 'When detected, switch to Mesen and press the paddle button.'
Write-Host 'To stop: return to this window and press Ctrl+C.'
Write-Host ''

try {
    & $tshark -i USBPcap1 -l -n -Y $filter -T fields `
        -e usb.bus_id -e usb.device_address -e usb.idVendor -e usb.idProduct -e usbhid.data 2>&1 |
        ForEach-Object {
            $line = [string]$_
            $parts = $line -split "`t", 5
            if ($parts.Count -ne 5) {
                if ($line -match '(error|failed|permission|capture)' -and $line -notmatch 'Capturing on') {
                    Write-Host $line -ForegroundColor DarkYellow
                }
                return
            }

            $bus = 0
            $dev = 0
            if (-not [int]::TryParse($parts[0], [ref]$bus) -or
                -not [int]::TryParse($parts[1], [ref]$dev)) { return }

            $vendorHex = $parts[2] -replace '^0x', ''
            $productHex = $parts[3] -replace '^0x', ''
            if ($vendorHex -match '^[0-9a-fA-F]+$' -and $productHex -match '^[0-9a-fA-F]+$') {
                if ([Convert]::ToInt32($vendorHex, 16) -eq 0x0AE4 -and
                    [Convert]::ToInt32($productHex, 16) -eq 0x0701) {
                    $script:targetBus = $bus
                    $script:targetDevice = $dev
                    $script:wasPressed = $false
                    Write-Host ("TAITO detected: bus {0}, address {1}" -f $bus, $dev) -ForegroundColor Green
                }
            }

            if ($bus -ne $script:targetBus -or $dev -ne $script:targetDevice) { return }

            # TShark can return '0001000000' or '00:01:00:00:00'.
            $hex = $parts[4] -replace '[^a-fA-F0-9]', ''
            if ($hex.Length -ne 10) { return }
            # 2nd byte bit 0 was observed to change 00 -> 01 when pressed.
            $secondByte = [Convert]::ToInt32($hex.Substring(2, 2), 16)
            $pressed = ($secondByte -band 1) -ne 0
            if ($pressed -and -not $script:wasPressed) {
                if ([EgretFireKey]::IsMesenActive()) {
                    [EgretFireKey]::TapSpace()
                    Write-Host 'Fire!' -ForegroundColor Cyan
                } else {
                    Write-Host 'Button detected (Mesen is not active)' -ForegroundColor DarkGray
                }
            }
            $script:wasPressed = $pressed
        }
} catch {
    Write-Host ('Capture failed: ' + $_.Exception.Message) -ForegroundColor Red
    Read-Host 'Press Enter to exit'
}
