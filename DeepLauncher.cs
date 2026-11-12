using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;

internal static class DeepLauncher
{
    private const string AppTitle = "deep";
    private const int UserCancelledElevation = 1223;

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            byte[] script = ReadEmbeddedScript();

            if (args.Length == 2 && args[0] == "--verify")
            {
                WriteVerificationReport(script, args[1]);
                return 0;
            }

            if (!IsAdministrator())
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = Assembly.GetExecutingAssembly().Location,
                        Arguments = "--elevated",
                        UseShellExecute = true,
                        Verb = "runas",
                        WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
                    });
                }
                catch (Win32Exception ex)
                {
                    if (ex.NativeErrorCode != UserCancelledElevation)
                        throw;
                }
                return 0;
            }

            RunSetup(script);
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "deep could not start the setup.\r\n\r\n" + ex.Message,
                AppTitle,
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
    }

    private static bool IsAdministrator()
    {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    private static byte[] ReadEmbeddedScript()
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        string resourceName = null;
        foreach (string name in assembly.GetManifestResourceNames())
        {
            if (name.Equals("setup.ps1", StringComparison.OrdinalIgnoreCase) ||
                name.EndsWith(".setup.ps1", StringComparison.OrdinalIgnoreCase))
            {
                resourceName = name;
                break;
            }
        }

        if (resourceName == null)
            throw new InvalidOperationException("The embedded setup script is missing.");

        using (Stream stream = assembly.GetManifestResourceStream(resourceName))
        {
            if (stream == null)
                throw new InvalidOperationException("The embedded setup script could not be opened.");

            using (MemoryStream buffer = new MemoryStream())
            {
                stream.CopyTo(buffer);
                return buffer.ToArray();
            }
        }
    }

    private static void RunSetup(byte[] script)
    {
        string scriptPath = Path.Combine(
            Path.GetTempPath(),
            "deep-" + Guid.NewGuid().ToString("N") + ".ps1");

        try
        {
            File.WriteAllBytes(scriptPath, script);
            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = Path.Combine(
                    Environment.SystemDirectory,
                    @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File \"" + scriptPath + "\"",
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            using (Process process = Process.Start(startInfo))
            {
                if (process == null)
                    throw new InvalidOperationException("Windows PowerShell did not start.");
                process.WaitForExit();
                if (process.ExitCode != 0)
                    throw new InvalidOperationException(
                        "Windows PowerShell exited with code " + process.ExitCode + ".");
            }
        }
        finally
        {
            if (File.Exists(scriptPath))
                File.Delete(scriptPath);
        }
    }

    private static void WriteVerificationReport(byte[] script, string reportPath)
    {
        string text = Encoding.UTF8.GetString(script);
        Match version = Regex.Match(text, @"(?m)^\$Version\s*=\s*'([^']+)'");
        if (!version.Success)
            throw new InvalidOperationException("The embedded script version could not be read.");

        string hash;
        using (SHA256 sha256 = SHA256.Create())
        {
            byte[] digest = sha256.ComputeHash(script);
            StringBuilder value = new StringBuilder(digest.Length * 2);
            foreach (byte item in digest)
                value.Append(item.ToString("X2"));
            hash = value.ToString();
        }

        File.WriteAllText(
            reportPath,
            "Version=" + version.Groups[1].Value + Environment.NewLine +
            "ScriptSHA256=" + hash + Environment.NewLine,
            new UTF8Encoding(false));
    }
}
