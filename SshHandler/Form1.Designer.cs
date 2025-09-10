partial class Form1
{
    /// <summary>
    /// Required designer variable.
    /// </summary>
    private System.ComponentModel.IContainer components = null;

    /// <summary>
    /// Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    /// <summary>
    /// Required method for Designer support - do not modify
    /// the contents of this method with the code editor.
    /// </summary>
    private void InitializeComponent()
    {
        this.label1 = new System.Windows.Forms.Label();
        this.targetTextBox = new System.Windows.Forms.TextBox();
        this.legacyCheckBox = new System.Windows.Forms.CheckBox();
        this.connectButton = new System.Windows.Forms.Button();
        this.cancelButton = new System.Windows.Forms.Button();
        this.SuspendLayout();
        // 
        // label1
        // 
        this.label1.AutoSize = true;
        this.label1.Location = new System.Drawing.Point(12, 15);
        this.label1.Name = "label1";
        this.label1.Size = new System.Drawing.Size(73, 15);
        this.label1.TabIndex = 0;
        this.label1.Text = "Connect to:";
        // 
        // targetTextBox
        // 
        this.targetTextBox.Location = new System.Drawing.Point(15, 33);
        this.targetTextBox.Name = "targetTextBox";
        this.targetTextBox.Size = new System.Drawing.Size(357, 23);
        this.targetTextBox.TabIndex = 1;
        // 
        // legacyCheckBox
        // 
        this.legacyCheckBox.AutoSize = true;
        this.legacyCheckBox.Location = new System.Drawing.Point(15, 71);
        this.legacyCheckBox.Name = "legacyCheckBox";
        this.legacyCheckBox.Size = new System.Drawing.Size(206, 19);
        this.legacyCheckBox.TabIndex = 2;
        this.legacyCheckBox.Text = "Enable Legacy Mode (for old devices)";
        this.legacyCheckBox.UseVisualStyleBackColor = true;
        // 
        // connectButton
        // 
        this.connectButton.Location = new System.Drawing.Point(297, 106);
        this.connectButton.Name = "connectButton";
        this.connectButton.Size = new System.Drawing.Size(75, 23);
        this.connectButton.TabIndex = 3;
        this.connectButton.Text = "Connect";
        this.connectButton.UseVisualStyleBackColor = true;
        this.connectButton.Click += new System.EventHandler(this.connectButton_Click);
        // 
        // cancelButton
        // 
        this.cancelButton.DialogResult = System.Windows.Forms.DialogResult.Cancel;
        this.cancelButton.Location = new System.Drawing.Point(216, 106);
        this.cancelButton.Name = "cancelButton";
        this.cancelButton.Size = new System.Drawing.Size(75, 23);
        this.cancelButton.TabIndex = 4;
        this.cancelButton.Text = "Cancel";
        this.cancelButton.UseVisualStyleBackColor = true;
        this.cancelButton.Click += new System.EventHandler(this.cancelButton_Click);
        // 
        // Form1
        // 
        this.AcceptButton = this.connectButton;
        this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 15F);
        this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        this.CancelButton = this.cancelButton;
        this.ClientSize = new System.Drawing.Size(384, 141);
        this.Controls.Add(this.cancelButton);
        this.Controls.Add(this.connectButton);
        this.Controls.Add(this.legacyCheckBox);
        this.Controls.Add(this.targetTextBox);
        this.Controls.Add(this.label1);
        this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        this.MinimizeBox = false;
        this.Name = "Form1";
        this.ShowIcon = false;
        this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
        this.Text = "SSH Connection";
        this.ResumeLayout(false);
        this.PerformLayout();
    }

    #endregion

    private System.Windows.Forms.Label label1;
    private System.Windows.Forms.TextBox targetTextBox;
    private System.Windows.Forms.CheckBox legacyCheckBox;
    private System.Windows.Forms.Button connectButton;
    private System.Windows.Forms.Button cancelButton;
}
