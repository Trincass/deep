using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;

internal static class DeepLauncher
{
    private const string AppTitle = "deep";

    [STAThread]
    private static int Main()
    {
        try
        {
            if (!IsAdministrator())
                throw new InvalidOperationException("deep requires administrator rights. Approve the Windows User Account Control prompt to continue.");

            RunSetup(ReadEmbeddedScript());
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
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            using (Process process = Process.Start(startInfo))
            {
                if (process == null)
                    throw new InvalidOperationException("Windows PowerShell did not start.");
                var standardOutput = process.StandardOutput.ReadToEndAsync();
                var standardError = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    string details = standardError.Result.Trim();
                    if (details.Length == 0)
                        details = standardOutput.Result.Trim();
                    if (details.Length > 3000)
                        details = details.Substring(0, 3000) + Environment.NewLine + "...";

                    string message = "Windows PowerShell exited with code " + process.ExitCode + ".";
                    if (details.Length > 0)
                        message += Environment.NewLine + Environment.NewLine + details;
                    throw new InvalidOperationException(message);
                }
            }
        }
        finally
        {
            if (File.Exists(scriptPath))
                File.Delete(scriptPath);
        }
    }

}
