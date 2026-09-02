using System.Drawing;
using System.Windows.Forms;
using WSNH.Services;

namespace WSNH.Forms;

public class ResultPopupForm : Form
{
    public ResultPopupForm(string text)
    {
        Text = "WSNH Result";
        FormBorderStyle = FormBorderStyle.SizableToolWindow;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(460, 320);
        TopMost = true;

        var textBox = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            Dock = DockStyle.Top,
            Height = ClientSize.Height - 44,
            Text = text
        };

        var copyButton = new Button { Text = "Copy", Width = 90, Left = 16, Top = ClientSize.Height - 36 };
        copyButton.Click += (_, _) => TextPaster.CopyToClipboard(text);

        var closeButton = new Button { Text = "Close", Width = 90, DialogResult = DialogResult.OK };
        closeButton.Left = ClientSize.Width - 16 - closeButton.Width;
        closeButton.Top = ClientSize.Height - 36;
        closeButton.Click += (_, _) => Close();

        Controls.Add(textBox);
        Controls.Add(copyButton);
        Controls.Add(closeButton);
    }
}
