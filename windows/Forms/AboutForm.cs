using System.Diagnostics;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;

namespace WSNH.Forms;

public class AboutForm : Form
{
    private const string SlackProfileUrl = "https://salesforce.enterprise.slack.com/team/U01G89VU4N7";

    public AboutForm()
    {
        Text = "About WSNH";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterScreen;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(300, 300);
        Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);

        var iconBox = new PictureBox
        {
            Image = Icon?.ToBitmap(),
            SizeMode = PictureBoxSizeMode.Zoom,
            Size = new Size(96, 96),
            Left = (ClientSize.Width - 96) / 2,
            Top = 20
        };

        var titleLabel = new Label
        {
            Text = "WSNH",
            Font = new Font("Segoe UI", 18, FontStyle.Bold),
            AutoSize = false,
            TextAlign = ContentAlignment.MiddleCenter,
            Left = 0,
            Top = 122,
            Width = ClientSize.Width
        };

        var taglineLabel = new Label
        {
            Text = "Words Smarter, Not Harder",
            TextAlign = ContentAlignment.MiddleCenter,
            Left = 0,
            Top = 158,
            Width = ClientSize.Width,
            AutoSize = false
        };

        var versionLabel = new Label
        {
            Text = $"Version {VersionString}",
            TextAlign = ContentAlignment.MiddleCenter,
            Left = 0,
            Top = 182,
            Width = ClientSize.Width,
            AutoSize = false,
            ForeColor = Color.DimGray
        };

        var updatedLabel = new Label
        {
            Text = $"Last updated {LastUpdatedString}",
            TextAlign = ContentAlignment.MiddleCenter,
            Left = 0,
            Top = 202,
            Width = ClientSize.Width,
            AutoSize = false,
            ForeColor = Color.DimGray
        };

        var creditPanel = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.LeftToRight,
            AutoSize = true,
            Left = 0,
            Top = 240,
            Width = ClientSize.Width,
            Anchor = AnchorStyles.Top
        };
        var creditLabel = new Label { Text = "Created with ❤ and SE Smarts by", AutoSize = true, Padding = new Padding(0, 3, 4, 0) };
        var creditLink = new LinkLabel { Text = "Amelia Ochodnicky", AutoSize = true, Padding = new Padding(0, 3, 0, 0) };
        creditLink.LinkClicked += (_, _) => OpenUrl(SlackProfileUrl);
        creditPanel.Controls.Add(creditLabel);
        creditPanel.Controls.Add(creditLink);

        // Center the credit line as a whole, since FlowLayoutPanel sizing
        // makes exact centering via Anchor alone unreliable.
        Shown += (_, _) => creditPanel.Left = (ClientSize.Width - creditPanel.Width) / 2;

        Controls.AddRange(new Control[] { iconBox, titleLabel, taglineLabel, versionLabel, updatedLabel, creditPanel });
    }

    private static string VersionString
    {
        get
        {
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            return version == null ? "2.0" : $"{version.Major}.{version.Minor}";
        }
    }

    /// <summary>
    /// Reads the compiled exe's own file modification date directly, so
    /// this is always accurate with zero manual date-stamping needed.
    /// </summary>
    private static string LastUpdatedString
    {
        get
        {
            try
            {
                var date = File.GetLastWriteTime(Application.ExecutablePath);
                return date.ToString("MMMM d, yyyy");
            }
            catch
            {
                return "unknown";
            }
        }
    }

    private static void OpenUrl(string url)
    {
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch { /* not fatal if the default browser can't be launched */ }
    }
}
