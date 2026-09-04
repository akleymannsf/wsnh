using System.Drawing;
using System.Windows.Forms;
using WSNH.Services;

namespace WSNH.Forms;

/// <summary>
/// First-run screen explaining what WSNH is, how to use it, and what comes
/// installed by default -- aimed at a business user, not a technical one.
/// Reachable again afterward via the tray menu's "Welcome Guide…" item.
/// </summary>
public class WelcomeForm : Form
{
    public event Action? OpenPreferencesRequested;

    public WelcomeForm()
    {
        Text = "Welcome to WSNH";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterScreen;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(480, 600);
        Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);

        var scroll = new Panel
        {
            Left = 0,
            Top = 0,
            Width = ClientSize.Width,
            Height = ClientSize.Height - 56,
            AutoScroll = true
        };

        var content = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoSize = true,
            Width = scroll.Width - 24,
            Padding = new Padding(16)
        };

        content.Controls.Add(Heading("Welcome to WSNH 🦕"));
        content.Controls.Add(Body("WSNH -- \"Words Smarter, Not Harder\" -- rewrites text with AI, right where you're typing, using a hotkey. Select some text anywhere on your PC, press a hotkey, and it gets rewritten in place."));

        content.Controls.Add(SubHeading("Two ways to use it"));
        content.Controls.Add(Body("1. AI rewrite: select text, press a hotkey, and the AI rewrites it based on a prompt you define (e.g. \"make this ALL CAPS\" or \"make this sound professional\")."));
        content.Controls.Add(Body("2. Snippets: save a block of text once, then drop it in anywhere -- either with its own hotkey, or by typing a short shortcut (like \";sig\") and pressing Space/Tab/Enter. No AI involved, works offline, instant."));

        content.Controls.Add(SubHeading("What's already set up for you"));
        foreach (var action in PromptStore.Shared.Actions)
        {
            content.Controls.Add(Body($"• {action.Name} — {action.HotKeyDisplayString}"));
        }
        content.Controls.Add(Body("Snippets start out empty -- add your own from Preferences whenever you're ready."));

        content.Controls.Add(SubHeading("Before anything works: add your API key"));
        content.Controls.Add(Body("Open Preferences and paste in your API key (Salesforce LLM Gateway Express, or your own OpenAI key). The AI rewrite hotkeys won't work until that's set -- Snippets work right away, no key needed."));

        content.Controls.Add(SubHeading("If the AI seems slow"));
        content.Controls.Add(Body("A balloon tip pops up from the tray icon the moment a rewrite starts, so you know it heard your hotkey. If the AI Gateway is having a slow moment, WSNH gives up after 25 seconds and lets you know, rather than leaving you waiting indefinitely."));

        content.Controls.Add(SubHeading("One more thing"));
        content.Controls.Add(Body("The first time you open WSNH, Windows may warn that it's from an \"unrecognized publisher\" -- that's expected for an internal tool like this one. Click \"More info\" then \"Run anyway\" to continue."));

        scroll.Controls.Add(content);

        var maybeLaterButton = new Button { Text = "Maybe later", Width = 110, Left = 16, Top = ClientSize.Height - 44 };
        maybeLaterButton.Click += (_, _) => Close();

        var openPrefsButton = new Button { Text = "Open Preferences", Width = 150 };
        openPrefsButton.Left = ClientSize.Width - 16 - openPrefsButton.Width;
        openPrefsButton.Top = ClientSize.Height - 44;
        openPrefsButton.Click += (_, _) =>
        {
            OpenPreferencesRequested?.Invoke();
            Close();
        };

        Controls.Add(scroll);
        Controls.Add(maybeLaterButton);
        Controls.Add(openPrefsButton);
    }

    private static Label Heading(string text) => new()
    {
        Text = text,
        Font = new Font("Segoe UI", 16, FontStyle.Bold),
        AutoSize = true,
        Margin = new Padding(0, 0, 0, 12)
    };

    private static Label SubHeading(string text) => new()
    {
        Text = text,
        Font = new Font("Segoe UI", 11, FontStyle.Bold),
        AutoSize = true,
        Margin = new Padding(0, 16, 0, 6)
    };

    private static Label Body(string text) => new()
    {
        Text = text,
        AutoSize = true,
        MaximumSize = new Size(420, 0),
        Margin = new Padding(0, 0, 0, 6)
    };
}
