using System;
using System.Collections.Generic;
using EgretButtons;

public static class ButtonTests
{
    private static int checks;
    private static void Check(bool value, string message)
    {
        checks++;
        if (!value) throw new Exception(message);
    }
    private static Dictionary<string, string> Mapping(bool allDistinct)
    {
        return new Dictionary<string, string> {
            { "right", "Space" }, { "left", allDistinct ? "Z" : "Space" },
            { "topLeft", allDistinct ? "X" : null }, { "topRight", allDistinct ? "Tab" : null },
            { "topBottom", "Enter" }
        };
    }
    private static void Change(List<KeyChange> changes, byte key, bool down, string context)
    {
        Check(changes.Count == 1 && changes[0].Key == key && changes[0].Down == down, context);
    }
    private static string Report(int mask)
    {
        int first = ((mask & 2) != 0 ? 0x80 : 0) | ((mask & 4) != 0 ? 2 : 0) |
                    ((mask & 8) != 0 ? 4 : 0) | ((mask & 16) != 0 ? 0x10 : 0);
        return first.ToString("X2") + ((mask & 1) != 0 ? "01" : "00") + "000000";
    }
    public static int Run()
    {
        checks = 0;
        // Validate native packet contents without injecting any keyboard input.
        byte[] virtualKeys = { 0x20, 0x0D, 0x5A, 0x58, 0x25, 0x2E };
        byte[] scanCodes = { 0x39, 0x1C, 0x2C, 0x2D, 0x4B, 0x53 };
        for (int i = 0; i < virtualKeys.Length; i++)
        {
            KeyboardPacket down = new KeyboardPacket(virtualKeys[i], true);
            KeyboardPacket up = new KeyboardPacket(virtualKeys[i], false);
            uint extended = i >= 4 ? 1u : 0u;
            Check(down.Key == virtualKeys[i] && down.ScanCode == scanCodes[i] && down.Flags == extended,
                  "MAME-compatible key down packet " + virtualKeys[i]);
            Check(up.Key == virtualKeys[i] && up.ScanCode == scanCodes[i] && up.Flags == (extended | 2u),
                  "MAME-compatible key up packet " + virtualKeys[i]);
        }
        string[] samples = { "0001000000", "8000000000", "0200000000", "0400000000", "1000000000" };
        for (int i = 0; i < samples.Length; i++)
        {
            int mask;
            Check(ButtonState.TryDecode(samples[i], out mask) && mask == (1 << i), "User sample " + i);
        }
        for (int i = 0; i < 32; i++)
        {
            int mask;
            Check(ButtonState.TryDecode(Report(i), out mask) && mask == i, "Combined report " + i);
        }
        int parsed;
        Check(ButtonState.TryDecode("80:01:00:00:00", out parsed) && parsed == 3, "Colon-separated bytes");
        Check(ButtonState.TryDecode("96 01 FF FF FF", out parsed) && parsed == 31, "Motion bytes do not affect buttons");
        foreach (string bad in new string[] { null, "", "0001", "000100000000", "gg01000000", "0001000000,0000000000" })
            Check(!ButtonState.TryDecode(bad, out parsed), "Reject malformed report");
        Check(KeyNames.Resolve(null) == 0, "Disabled");
        Check(KeyNames.Resolve("space") == 32 && KeyNames.Resolve("Enter") == 13, "Named keys");
        Check(KeyNames.Resolve("z") == 90 && KeyNames.Resolve("7") == 55, "Letters and numbers");
        Check(KeyNames.Resolve("F12") == 123 && KeyNames.Resolve("Left") == 37, "Function and arrow keys");
        foreach (string bad in new string[] { "", "Spcae", "Ctrl+Z", "F13" })
        {
            bool failed = false;
            try { KeyNames.Resolve(bad); } catch (ArgumentException) { failed = true; }
            Check(failed, "Reject unknown key");
        }

        ButtonState state = new ButtonState(Mapping(false));
        Change(state.Report(1), 32, true, "Right down without application activation");
        Check(state.Report(1).Count == 0, "Repeated report does not retrigger");
        Check(state.Report(3).Count == 0, "Second source does not retrigger Space");
        Check(state.Report(2).Count == 0, "Right release keeps Space held by left");
        Change(state.Report(0), 32, false, "Last source releases Space");
        Check(state.Report(12).Count == 0, "Unassigned upper buttons");
        Change(state.Report(16), 13, true, "Start down");
        Change(state.Report(17), 32, true, "Fire while Start held");
        Change(state.Report(1), 13, false, "Start release leaves Fire");
        Check(state.Report(1).Count == 0, "Held input stays held without retriggering");
        Change(state.Report(0), 32, false, "Physical release clears held key");
        Change(state.Report(1), 32, true, "New press remains enabled");
        Change(state.Reset(), 32, false, "Shutdown releases held key");
        Check(state.Reset().Count == 0, "Repeated cleanup is harmless");
        Change(state.Report(16), 13, true, "Input still enabled after reset");
        Change(state.Reset(), 13, false, "Cleanup releases Enter");

        ButtonState letters = new ButtonState(Mapping(true));
        Change(letters.Report(2), 90, true, "Z works without application activation");
        Change(letters.Report(6), 88, true, "X works alongside held Z");
        Change(letters.Report(4), 90, false, "Z release keeps X held");
        Change(letters.Reset(), 88, false, "Cleanup releases X");

        // Exhaustively compare every pair of physical button states, including duplicates.
        foreach (bool distinct in new bool[] { false, true })
        {
            Dictionary<string, string> mapping = Mapping(distinct);
            for (int before = 0; before < 32; before++)
                for (int after = 0; after < 32; after++)
                {
                    ButtonState model = new ButtonState(mapping);
                    model.Report(before);
                    List<KeyChange> changes = model.Report(after);
                    HashSet<byte> oldKeys = Keys(mapping, before), newKeys = Keys(mapping, after);
                    int expected = 0;
                    foreach (byte key in oldKeys) if (!newKeys.Contains(key)) expected++;
                    foreach (byte key in newKeys) if (!oldKeys.Contains(key)) expected++;
                    Check(changes.Count == expected, "Transition count");
                    foreach (KeyChange change in changes)
                        Check(change.Down ? !oldKeys.Contains(change.Key) && newKeys.Contains(change.Key)
                                          : oldKeys.Contains(change.Key) && !newKeys.Contains(change.Key),
                              "Transition matches physical sources");
                }
        }

        ReportRouter router = new ReportRouter(Mapping(false));
        Check(router.ProcessLine("1\t17\t\t\t0001000000").Count == 0, "Ignore input before identification");
        router.ProcessLine("1\t17\t0x0ae4\t0x0701\t");
        Check(router.Notice != null, "Identify TAITO");
        Check(router.ProcessLine("2\t17\t\t\t0001000000").Count == 0, "Ignore other bus");
        Check(router.ProcessLine("1\t18\t\t\t0001000000").Count == 0, "Ignore other device");
        Change(router.ProcessLine("1\t17\t\t\t8001000000"), 32, true, "Combined report routing");
        Check(router.ProcessLine("1\t17\t\t\t8000000000").Count == 0, "Route overlapping release");
        Check(router.ProcessLine("garbage").Count == 0, "Ignore malformed line");
        Check(router.ProcessLine("1\t17\t\t\tzz").Count == 0, "Ignore malformed data without releasing");
        Change(router.ProcessLine("1\t19\t0ae4\t0701\t"), 32, false, "Reconnect releases prior state");
        Check(router.ProcessLine("1\t17\t\t\t0001000000").Count == 0, "Ignore old device address");
        Change(router.ProcessLine("1\t19\t\t\t1000000000"), 13, true, "New address works");
        Change(router.ProcessLine("1\t19\t1234\t5678\t"), 13, false, "Address reuse releases");
        Check(router.ProcessLine("1\t19\t\t\t0001000000").Count == 0, "Other device cannot inject");
        return checks;
    }

    private static HashSet<byte> Keys(Dictionary<string, string> mapping, int mask)
    {
        HashSet<byte> result = new HashSet<byte>();
        for (int i = 0; i < ButtonState.Names.Length; i++)
        {
            byte key = KeyNames.Resolve(mapping[ButtonState.Names[i]]);
            if ((mask & (1 << i)) != 0 && key != 0) result.Add(key);
        }
        return result;
    }
}
