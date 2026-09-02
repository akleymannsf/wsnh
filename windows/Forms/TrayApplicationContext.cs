using System.Drawing;
using System.Windows.Forms;
using WSNH.Models;
using WSNH.Services;

namespace WSNH.Forms;

/// <summary>
/// The tray-icon equivalent of the Mac app's status bar item + AppDelegate.
/// Owns the NotifyIcon, wires up hotkey triggers, and hosts the various
/// windows (Preferences, Welcome, About, result popups).
/// </summary>
public class TrayApplicationContext : ApplicationContext
{
    private readonly NotifyIcon _trayIcon;
    private readonly List<ResultPopupForm> _resultWindows = new();

    // Guards against a burst of hotkey presses firing a burst of AI calls.
    // Nothing visibly happens the instant you press the hotkey -- the popup
    // only appears once the network call finishes -- so pressing it again
    // while impatient would otherwise queue up another full request on top,
    // and another, and another. Only one request runs at a time; a repeat
    // press while one's in flight just beeps instead of piling on.
    private bool _isPromptRequestInFlight;

    public TrayApplicationContext()
    {
        var icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);

        var menu = new ContextMenuStrip();
        menu.Items.Add("Welcome Guide…", null, (_, _) => OpenWelcome());
        menu.Items.Add("About WSNH", null, (_, _) => OpenAbout());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Preferences…", null, (_, _) => OpenSettings());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit WSNH", null, (_, _) => Quit());

        _trayIcon = new NotifyIcon
        {
            Icon = icon,
            Text = "WSNH",
            Visible = true,
            ContextMenuStrip = menu
        };
        _trayIcon.DoubleClick += (_, _) => OpenSettings();

        HotKeyManager.Shared.OnTrigger = HandleTrigger;
        HotKeyManager.Shared.RegisterAll(PromptStore.Shared.Actions);

        SnippetHotKeyManager.Shared.OnTrigger = HandleSnippetHotKey;
        SnippetHotKeyManager.Shared.RegisterAll(SnippetStore.Shared.Snippets);
        TypedTriggerWatcher.Shared.ReloadShortcuts(SnippetStore.Shared.Snippets);
        TypedTriggerWatcher.Shared.Start();

        if (!SettingsStore.HasShownWelcome)
        {
            SettingsStore.HasShownWelcome = true;
            OpenWelcome();
        }
    }

    private SettingsForm? _settingsForm;
    private void OpenSettings()
    {
        if (_settingsForm == null || _settingsForm.IsDisposed)
        {
            _settingsForm = new SettingsForm();
        }
        _settingsForm.Show();
        _settingsForm.Activate();
    }

    private WelcomeForm? _welcomeForm;
    private void OpenWelcome()
    {
        if (_welcomeForm == null || _welcomeForm.IsDisposed)
        {
            _welcomeForm = new WelcomeForm();
            _welcomeForm.OpenPreferencesRequested += OpenSettings;
        }
        _welcomeForm.Show();
        _welcomeForm.Activate();
    }

    private AboutForm? _aboutForm;
    private void OpenAbout()
    {
        if (_aboutForm == null || _aboutForm.IsDisposed)
        {
            _aboutForm = new AboutForm();
        }
        _aboutForm.Show();
        _aboutForm.Activate();
    }

    private void Quit()
    {
        _trayIcon.Visible = false;
        TypedTriggerWatcher.Shared.Stop();
        Application.Exit();
    }

    // MARK: - Prompt Action hotkey trigger flow

    private async void HandleTrigger(PromptAction action)
    {
        if (_isPromptRequestInFlight)
        {
            System.Media.SystemSounds.Beep.Play();
            return;
        }
        _isPromptRequestInFlight = true;

        try
        {
            var text = await SelectedTextGrabber.CaptureSelectedTextAsync();
            if (string.IsNullOrEmpty(text)) return;

            try
            {
                var result = await OpenAIClient.RunAsync(action.Model, action.PromptTemplate, text);
                await DeliverResultAsync(result, action);
            }
            catch (OpenAIException ex)
            {
                ShowError(ex.Message);
            }
        }
        finally
        {
            _isPromptRequestInFlight = false;
        }
    }

    // MARK: - Snippet hotkey trigger flow

    private void HandleSnippetHotKey(Snippet snippet)
    {
        SnippetInserter.InsertAtCursor(snippet);
    }

    private async Task DeliverResultAsync(string result, PromptAction action)
    {
        switch (action.OutputMode)
        {
            case OutputMode.AutoPaste:
                await TextPaster.PasteReplacingSelectionAsync(result);
                break;

            case OutputMode.Popup:
                ShowResultWindow(result);
                break;

            case OutputMode.Ask:
                using (var dialog = new AskResultDialog(result))
                {
                    var response = dialog.ShowDialog();
                    if (response == DialogResult.Yes)
                    {
                        await TextPaster.PasteReplacingSelectionAsync(result);
                    }
                    else if (response == DialogResult.No)
                    {
                        TextPaster.CopyToClipboard(result);
                    }
                }
                break;
        }
    }

    private void ShowResultWindow(string result)
    {
        var window = new ResultPopupForm(result);
        _resultWindows.Add(window);
        window.FormClosed += (_, _) => _resultWindows.Remove(window);
        window.Show();
        window.Activate();
    }

    private static void ShowError(string message)
    {
        MessageBox.Show(message, "WSNH Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }
}

/// <summary>"Apply rewritten text?" dialog for PromptActions set to Ask.</summary>
internal class AskResultDialog : Form
{
    public AskResultDialog(string result)
    {
        Text = "Apply rewritten text?";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterScreen;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(420, 260);

        var textBox = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            Left = 16,
            Top = 16,
            Width = 388,
            Height = 160,
            Text = result
        };

        var pasteButton = new Button { Text = "Paste && Replace", DialogResult = DialogResult.Yes, Left = 16, Top = 190, Width = 120 };
        var copyButton = new Button { Text = "Copy Only", DialogResult = DialogResult.No, Left = 144, Top = 190, Width = 100 };
        var cancelButton = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Left = 252, Top = 190, Width = 90 };

        Controls.AddRange(new Control[] { textBox, pasteButton, copyButton, cancelButton });
        CancelButton = cancelButton;
    }
}
