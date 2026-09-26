// Diagnostic only: asks Windows Attachment Services to SAVE/check an existing download.
// No Execute/Launch entry point, no UI bypass, no security-policy changes.
using System;
using System.Runtime.InteropServices;

namespace Spoticraft.SecurityDiagnostics {
    [ComImport, Guid("73DB1241-1E85-4581-8E4F-A81E1D0F8C57"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAttachmentSave {
        [PreserveSig] int SetClientTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
        [PreserveSig] int SetClientGuid(ref Guid client);
        [PreserveSig] int SetLocalPath([MarshalAs(UnmanagedType.LPWStr)] string path);
        [PreserveSig] int SetFileName([MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int SetSource([MarshalAs(UnmanagedType.LPWStr)] string source);
        [PreserveSig] int SetReferrer([MarshalAs(UnmanagedType.LPWStr)] string source);
        [PreserveSig] int CheckPolicy();
        [PreserveSig] int Prompt(IntPtr parent, uint prompt, out uint action);
        [PreserveSig] int Save();
    }
    public static class AttachmentCheck {
        public static string SaveOnly(string path, string source) {
            object instance = Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("4125DD96-E03A-4103-8F70-E0597D803B9C")));
            try {
                var attachment = (IAttachmentSave)instance;
                Marshal.ThrowExceptionForHR(attachment.SetClientTitle("Spoticraft security investigation (no execution)"));
                var id = new Guid("74df8947-ec4f-44ab-bd05-3874467a652c");
                Marshal.ThrowExceptionForHR(attachment.SetClientGuid(ref id));
                Marshal.ThrowExceptionForHR(attachment.SetLocalPath(path));
                Marshal.ThrowExceptionForHR(attachment.SetFileName(System.IO.Path.GetFileName(path)));
                Marshal.ThrowExceptionForHR(attachment.SetSource(source));
                Marshal.ThrowExceptionForHR(attachment.SetReferrer("https://github.com/blxcksh2dow/Spoticraft"));
                // Save can quarantine or delete the file; we do not recreate or restore it.
                return "0x" + unchecked((uint)attachment.Save()).ToString("X8");
            } finally { Marshal.FinalReleaseComObject(instance); }
        }
    }
}
