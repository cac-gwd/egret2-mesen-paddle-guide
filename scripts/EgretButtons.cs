using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace EgretButtons
{
    public static class KeyNames
    {
        public static byte Resolve(string name)
        {
            if (name == null) return 0;
            string key = name.Trim().ToUpperInvariant();
            if (key.Length == 1 && ((key[0] >= 'A' && key[0] <= 'Z') ||
                                   (key[0] >= '0' && key[0] <= '9'))) return (byte)key[0];
            int number;
            if (key.StartsWith("F") && Int32.TryParse(key.Substring(1), out number) && number >= 1 && number <= 12)
                return (byte)(0x70 + number - 1);
            switch (key)
            {
                case "SPACE": return 0x20;
                case "ENTER": case "RETURN": return 0x0D;
                case "ESCAPE": case "ESC": return 0x1B;
                case "TAB": return 0x09;
                case "BACKSPACE": return 0x08;
                case "LEFT": return 0x25;
                case "UP": return 0x26;
                case "RIGHT": return 0x27;
                case "DOWN": return 0x28;
                case "HOME": return 0x24;
                case "END": return 0x23;
                case "PAGEUP": return 0x21;
                case "PAGEDOWN": return 0x22;
                case "INSERT": return 0x2D;
                case "DELETE": return 0x2E;
                default: throw new ArgumentException("Unsupported key name: '" + name + "'. Use null to disable a button.");
            }
        }
    }

    public sealed class KeyChange
    {
        public byte Key { get; private set; }
        public bool Down { get; private set; }
        public KeyChange(byte key, bool down) { Key = key; Down = down; }
    }

    // Pure state machine: no OS calls. Several physical buttons can share one key.
    public sealed class ButtonState
    {
        public static readonly string[] Names = { "right", "left", "topLeft", "topRight", "topBottom" };
        private readonly byte[] keys = new byte[5];
        private HashSet<byte> sent = new HashSet<byte>();
        private int physical;

        public ButtonState(IDictionary<string, string> mapping)
        {
            if (mapping == null || mapping.Count != Names.Length) throw new ArgumentException("Exactly five button mappings are required.");
            for (int i = 0; i < Names.Length; i++) keys[i] = KeyNames.Resolve(mapping[Names[i]]);
        }

        public static bool TryDecode(string data, out int mask)
        {
            mask = 0;
            if (data == null) return false;
            // Reject multiple reports, malformed data, and other report lengths.
            string hex = data.Trim().Replace(":", "").Replace(" ", "");
            if (hex.Length != 10) return false;
            byte[] bytes = new byte[5];
            for (int i = 0; i < bytes.Length; i++)
                if (!Byte.TryParse(hex.Substring(i * 2, 2), NumberStyles.AllowHexSpecifier,
                                   CultureInfo.InvariantCulture, out bytes[i])) return false;
            if ((bytes[1] & 0x01) != 0) mask |= 1;
            if ((bytes[0] & 0x80) != 0) mask |= 2;
            if ((bytes[0] & 0x02) != 0) mask |= 4;
            if ((bytes[0] & 0x04) != 0) mask |= 8;
            if ((bytes[0] & 0x10) != 0) mask |= 16;
            return true;
        }

        public List<KeyChange> Report(int mask)
        {
            physical = mask & 31;
            return Reconcile();
        }

        public List<KeyChange> Reset()
        {
            physical = 0;
            return Reconcile();
        }

        private List<KeyChange> Reconcile()
        {
            HashSet<byte> desired = new HashSet<byte>();
            // Global keyboard input: application focus does not gate button state.
            for (int i = 0; i < keys.Length; i++)
                if ((physical & (1 << i)) != 0 && keys[i] != 0) desired.Add(keys[i]);
            List<KeyChange> changes = new List<KeyChange>();
            foreach (byte key in sent) if (!desired.Contains(key)) changes.Add(new KeyChange(key, false));
            foreach (byte key in desired) if (!sent.Contains(key)) changes.Add(new KeyChange(key, true));
            sent = desired;
            return changes;
        }
    }

    // TShark routing is independent of keyboard injection, allowing offline testing.
    public sealed class ReportRouter
    {
        private int targetBus = -1;
        private int targetDevice = -1;
        public string Notice { get; private set; }
        public ButtonState State { get; private set; }
        public ReportRouter(IDictionary<string, string> mapping) { State = new ButtonState(mapping); }

        public List<KeyChange> ProcessLine(string line)
        {
            Notice = null;
            List<KeyChange> changes = new List<KeyChange>();
            string[] parts = line.Split(new char[] { '\t' }, 5);
            int bus, device, vendor, product, mask;
            if (parts.Length != 5 || !Int32.TryParse(parts[0], out bus) || !Int32.TryParse(parts[1], out device)) return changes;
            if (TryHex(parts[2], out vendor) && TryHex(parts[3], out product))
            {
                if (vendor == 0x0AE4 && product == 0x0701)
                {
                    changes.AddRange(State.Reset());
                    targetBus = bus;
                    targetDevice = device;
                    Notice = String.Format("TAITO detected: bus {0}, address {1}", bus, device);
                }
                else if (bus == targetBus && device == targetDevice)
                {
                    changes.AddRange(State.Reset());
                    targetBus = targetDevice = -1;
                }
            }
            if (bus == targetBus && device == targetDevice && ButtonState.TryDecode(parts[4], out mask))
                changes.AddRange(State.Report(mask));
            return changes;
        }

        private static bool TryHex(string value, out int number)
        {
            if (value.StartsWith("0x", StringComparison.OrdinalIgnoreCase)) value = value.Substring(2);
            return Int32.TryParse(value, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out number);
        }
    }

    // MAME's win32 provider identifies keys from the message scan code.
    // Sending only a virtual key (scan code 0) works in some apps but not MAME.
    public sealed class KeyboardPacket
    {
        [DllImport("user32.dll", ExactSpelling = true)]
        private static extern uint MapVirtualKeyW(uint code, uint mapType);

        public byte Key { get; private set; }
        public byte ScanCode { get; private set; }
        public uint Flags { get; private set; }

        public KeyboardPacket(byte key, bool down)
        {
            // MAPVK_VK_TO_VSC_EX includes the E0 prefix for navigation keys.
            uint scan = MapVirtualKeyW(key, 4);
            if ((scan & 0xFF) == 0)
                throw new ArgumentException("No keyboard scan code for virtual key " + key);
            Key = key;
            ScanCode = (byte)(scan & 0xFF);
            // Keep dedicated navigation keys distinct from their numpad equivalents,
            // including layouts that return the scan without its E0 prefix.
            bool navigation = (key >= 0x21 && key <= 0x28) || key == 0x2D || key == 0x2E;
            Flags = (((scan & 0xFF00) == 0xE000 || navigation) ? 1u : 0u) | (down ? 0u : 2u);
        }
    }

    internal static class NativeKeys
    {
        [DllImport("user32.dll")] private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);

        internal static void Send(KeyChange change)
        {
            KeyboardPacket packet = new KeyboardPacket(change.Key, change.Down);
            keybd_event(packet.Key, packet.ScanCode, packet.Flags, UIntPtr.Zero);
        }
    }

    public sealed class Capture
    {
        private readonly ConcurrentQueue<string> messages = new ConcurrentQueue<string>();
        private readonly CancellationTokenSource stop = new CancellationTokenSource();
        private Task worker;
        private Process process;
        public string ErrorMessage { get; private set; }
        public bool IsRunning { get { return worker != null && !worker.IsCompleted; } }

        public void Start(string executable, string captureInterface, IDictionary<string, string> mapping)
        {
            if (worker != null) throw new InvalidOperationException("Capture was already started.");
            if (!System.Text.RegularExpressions.Regex.IsMatch(captureInterface, "^USBPcap[1-9][0-9]*$"))
                throw new ArgumentException("Invalid USBPcap interface.");
            ReportRouter router = new ReportRouter(mapping);
            worker = Task.Run(() => Run(executable, captureInterface, router));
        }

        public string[] DrainMessages()
        {
            List<string> result = new List<string>();
            string message;
            while (messages.TryDequeue(out message)) result.Add(message);
            return result.ToArray();
        }

        private void Apply(IEnumerable<KeyChange> changes)
        {
            foreach (KeyChange change in changes)
            {
                NativeKeys.Send(change);
                messages.Enqueue(String.Format("Key {0}: 0x{1:X2}", change.Down ? "down" : "up", change.Key));
            }
        }

        private void Run(string executable, string captureInterface, ReportRouter router)
        {
            try
            {
                if (stop.IsCancellationRequested) return;
                ProcessStartInfo info = new ProcessStartInfo(executable,
                    "-i " + captureInterface + " -l -n -Y \"(usb.idVendor == 0x0ae4 && usb.idProduct == 0x0701) || usbhid.data\"" +
                    " -T fields -e usb.bus_id -e usb.device_address -e usb.idVendor -e usb.idProduct -e usbhid.data");
                info.UseShellExecute = false;
                info.CreateNoWindow = true;
                info.RedirectStandardOutput = true;
                info.RedirectStandardError = true;
                process = new Process();
                process.StartInfo = info;
                process.ErrorDataReceived += (sender, args) => { if (!String.IsNullOrEmpty(args.Data)) messages.Enqueue(args.Data); };
                process.Start();
                // Native stderr never enters PowerShell's error stream (Windows PS 5.1).
                process.BeginErrorReadLine();
                Task<string> pending = process.StandardOutput.ReadLineAsync();
                while (!stop.IsCancellationRequested)
                {
                    int count = 0;
                    while (pending.IsCompleted && count++ < 256 && !stop.IsCancellationRequested)
                    {
                        string line = pending.GetAwaiter().GetResult();
                        if (line == null)
                            throw new InvalidOperationException("TShark capture ended. Check the interface and USBPcap installation; see the messages above.");
                        Apply(router.ProcessLine(line));
                        if (router.Notice != null) messages.Enqueue(router.Notice);
                        pending = process.StandardOutput.ReadLineAsync();
                    }
                    if (!pending.IsCompleted) stop.Token.WaitHandle.WaitOne(5);
                }
            }
            catch (Exception error)
            {
                if (!stop.IsCancellationRequested) ErrorMessage = error.Message;
            }
            finally
            {
                Apply(router.State.Reset());
                if (process != null)
                {
                    try { if (!process.HasExited) process.Kill(); } catch (InvalidOperationException) { }
                    process.Dispose();
                    process = null;
                }
            }
        }

        public void Stop()
        {
            stop.Cancel();
            if (worker != null) worker.GetAwaiter().GetResult();
        }
    }
}
