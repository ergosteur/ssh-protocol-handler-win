using System;
using System.Windows.Forms;

public partial class Form1 : Form
{
    // This property will store the result for the main program
    public string FinalSshCommand { get; private set; }

    public Form1(string initialTarget)
    {
        InitializeComponent();
        targetTextBox.Text = initialTarget;
        // Select the text for easy editing
        targetTextBox.SelectAll();
        targetTextBox.Focus();
    }

    private void connectButton_Click(object sender, EventArgs e)
    {
        string target = targetTextBox.Text;
        bool useLegacy = legacyCheckBox.Checked;

        string legacyArgs = "-o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 " +
                            "-o HostKeyAlgorithms=+ssh-rsa " +
                            "-o MACs=+hmac-sha1,hmac-sha1-96";

        // Build the arguments for ssh.exe
        string arguments = $"-A -C {(useLegacy ? legacyArgs : "")} {target}";

        FinalSshCommand = arguments;
        this.DialogResult = DialogResult.OK; // Set dialog result to OK
        this.Close(); // Close the form
    }

    private void cancelButton_Click(object sender, EventArgs e)
    {
        this.DialogResult = DialogResult.Cancel; // Set dialog result to Cancel
        this.Close();
    }
}
