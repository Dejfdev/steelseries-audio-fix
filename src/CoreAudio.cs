using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace SteelFix {
    public enum DataFlow { Render = 0, Capture = 1, All = 2 }
    public enum Role { Console = 0, Multimedia = 1, Communications = 2 }
    [StructLayout(LayoutKind.Sequential)] public struct PropertyKey { public Guid fmtid; public int pid; }
    [StructLayout(LayoutKind.Explicit, Size=24)] public struct PropVariant { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr pointer; }
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] internal class MMDeviceEnumerator { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator {
        void EnumAudioEndpoints(DataFlow flow, int mask, out IMMDeviceCollection devices);
        [PreserveSig] int GetDefaultAudioEndpoint(DataFlow flow, Role role, out IMMDevice endpoint);
        void GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
        void RegisterEndpointNotificationCallback(IntPtr callback);
        void UnregisterEndpointNotificationCallback(IntPtr callback);
    }
    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceCollection { void GetCount(out uint count); void Item(uint index, out IMMDevice device); }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice {
        void Activate(ref Guid iid, int ctx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object instance);
        void OpenPropertyStore(int access, out IPropertyStore store);
        void GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        void GetState(out int state);
    }
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPropertyStore {
        void GetCount(out int count); void GetAt(int index, out PropertyKey key);
        void GetValue(ref PropertyKey key, out PropVariant value); void SetValue(ref PropertyKey key, ref PropVariant value); void Commit();
    }
    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioEndpointVolume {
        void RegisterControlChangeNotify(IntPtr notify); void UnregisterControlChangeNotify(IntPtr notify);
        void GetChannelCount(out uint channels); void SetMasterVolumeLevel(float db, IntPtr context); void SetMasterVolumeLevelScalar(float level, IntPtr context);
        void GetMasterVolumeLevel(out float db); void GetMasterVolumeLevelScalar(out float level);
        void SetChannelVolumeLevel(uint channel, float db, IntPtr context); void SetChannelVolumeLevelScalar(uint channel, float level, IntPtr context);
        void GetChannelVolumeLevel(uint channel, out float db); void GetChannelVolumeLevelScalar(uint channel, out float level);
        void SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, IntPtr context); void GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
        void GetVolumeStepInfo(out uint step, out uint count); void VolumeStepUp(IntPtr context); void VolumeStepDown(IntPtr context);
        void QueryHardwareSupport(out uint mask); void GetVolumeRange(out float min, out float max, out float increment);
    }
    // Windows has no documented general-purpose API for changing the user's default endpoint.
    // This widely used COM interface is undocumented and can change in a future Windows release.
    [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] internal class PolicyConfigClient { }
    [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPolicyConfig {
        void GetMixFormat(IntPtr device, IntPtr format); void GetDeviceFormat(IntPtr device, int isDefault, IntPtr format);
        void ResetDeviceFormat(IntPtr device); void SetDeviceFormat(IntPtr device, IntPtr format, IntPtr mix);
        void GetProcessingPeriod(IntPtr device, int isDefault, IntPtr defaultPeriod, IntPtr minimumPeriod);
        void SetProcessingPeriod(IntPtr device, IntPtr period); void GetShareMode(IntPtr device, IntPtr mode); void SetShareMode(IntPtr device, IntPtr mode);
        void GetPropertyValue(IntPtr device, IntPtr key, IntPtr value); void SetPropertyValue(IntPtr device, IntPtr key, IntPtr value);
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string device, Role role);
        void SetEndpointVisibility(IntPtr device, int visible);
    }
    public class Endpoint { public string Id {get;set;} public string Name {get;set;} public string Flow {get;set;} public float Volume {get;set;} public bool Muted {get;set;} }
    public static class Audio {
        [DllImport("ole32.dll")] static extern int PropVariantClear(ref PropVariant variant);
        static readonly Guid volumeGuid = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
        static IMMDeviceEnumerator Enumerator() { return (IMMDeviceEnumerator)new MMDeviceEnumerator(); }
        static IAudioEndpointVolume Volume(IMMDevice d) { object o; Guid g = volumeGuid; d.Activate(ref g, 23, IntPtr.Zero, out o); return (IAudioEndpointVolume)o; }
        static Endpoint Read(IMMDevice d, DataFlow flow) {
            string id; d.GetId(out id); IPropertyStore store; d.OpenPropertyStore(0, out store);
            var key = new PropertyKey { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 }; PropVariant value;
            store.GetValue(ref key, out value); string name = value.vt == 31 ? Marshal.PtrToStringUni(value.pointer) : id; PropVariantClear(ref value);
            var v = Volume(d); float level; bool muted; v.GetMasterVolumeLevelScalar(out level); v.GetMute(out muted);
            return new Endpoint { Id=id, Name=name, Flow=flow.ToString(), Volume=level, Muted=muted };
        }
        public static Endpoint[] List(DataFlow flow) {
            IMMDeviceCollection c; Enumerator().EnumAudioEndpoints(flow, 1, out c); uint count; c.GetCount(out count); var result = new List<Endpoint>();
            for (uint i=0; i<count; i++) { IMMDevice d; c.Item(i, out d); result.Add(Read(d, flow)); } return result.ToArray();
        }
        public static string DefaultId(DataFlow flow, Role role) {
            IMMDevice d; int hr=Enumerator().GetDefaultAudioEndpoint(flow, role, out d); if (hr == unchecked((int)0x80070490)) return null; Marshal.ThrowExceptionForHR(hr); if (d == null) throw new InvalidOperationException("Windows returned no endpoint."); string id; d.GetId(out id); return id;
        }
        public static void SetDefault(string id, Role role) { int hr=((IPolicyConfig)new PolicyConfigClient()).SetDefaultEndpoint(id, role); Marshal.ThrowExceptionForHR(hr); }
        public static void SetVolume(string id, float level, bool muted) {
            if (level < 0 || level > 1) throw new ArgumentOutOfRangeException("level");
            IMMDevice d; Enumerator().GetDevice(id, out d); var v=Volume(d); v.SetMasterVolumeLevelScalar(level, IntPtr.Zero); v.SetMute(muted, IntPtr.Zero);
        }
    }
}
