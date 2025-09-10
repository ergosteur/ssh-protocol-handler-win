using Microsoft.Win32;
using System;
using System.Diagnostics;
using System.Security.Principal;
using System.Windows.Forms;

static class Program
{
    private const string ProtocolName = "ssh";

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        // If no arguments, run setup mode.
        if (args.Length == 0)
        {
            SetupHandler();
        }
        // Otherwise, run handler mode.
        else
        {
            HandleConnection(args[0]);
        }
    }

    static void HandleConnection(string url)
    {
        string target = url.Replace("ssh://", "").TrimEnd('/');
        if (!target.Contains("@"))
        {
            target = $"{Environment.UserName}@{target}";
        }

        // Show the form as a dialog
        using (var form = new Form1(target))
        {
            if (form.ShowDialog() == DialogResult.OK)
            {
                // If user clicked "Connect", run the command
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "ssh.exe",
                    Arguments = form.FinalSshCommand,
                    UseShellExecute = true,
                    CreateNoWindow = false
                };
                Process.Start(psi);
            }
        }
    }

    static void SetupHandler()
    {
        if (!IsAdmin())
        {
            MessageBox.Show("Please run this application as an administrator to register the URL handler.", "Admin Privileges Required", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        // The path is simple and correct because it's a native app
        string exePath = Application.ExecutablePath;
        string commandStr = $"\"{exePath}\" \"%1\"";

        var confirmResult = MessageBox.Show(
            "This will register this application to handle all ssh:// links.\n\n" +
            $"Command:\n{commandStr}\n\n" +
            "Do you want to proceed?",
            "Registry Setup",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Information);

        if (confirmResult == DialogResult.Yes)
        {
            try
            {
                // Write the keys to HKEY_CLASSES_ROOT
                using (RegistryKey key = Registry.ClassesRoot.CreateSubKey(ProtocolName))
                {
                    key.SetValue("", $"URL:{ProtocolName} Protocol");
                    key.SetValue("URL Protocol", "");
                }
                using (RegistryKey key = Registry.ClassesRoot.CreateSubKey($"{ProtocolName}\\shell\\open\\command"))
                {
                    key.SetValue("", commandStr);
                }
                MessageBox.Show("Successfully registered ssh:// protocol handler!", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to write to registry:\n{ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    private static bool IsAdmin()
    {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }
}
