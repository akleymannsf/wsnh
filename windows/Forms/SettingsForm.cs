using System.Drawing;
using System.Windows.Forms;
using WSNH.Models;
using WSNH.Services;

namespace WSNH.Forms;

public class SettingsForm : Form
{
    private readonly TextBox _apiKeyField = new() { Width = 380, UseSystemPasswordChar = true };
    private readonly CheckBox _showKeyCheckBox = new() { Text = "Show", AutoSize = true };
    private readonly TextBox _baseUrlField = new() { Width = 380 };
    private readonly ListBox _actionsList = new() { Width = 420, Height = 220 };
    private readonly ListBox _snippetsList = new() { Width = 420, Height = 220 };

    public SettingsForm()
    {
        Text = "WSNH Preferences";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterScreen;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(500, 640);
        Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);

        var tabs = new TabControl { Dock = DockStyle.Top, Height = 560 };
        tabs.TabPages.Add(BuildConnectionTab());
        tabs.TabPages.Add(BuildActionsTab());
        tabs.TabPages.Add(BuildSnippetsTab());
        tabs.TabPages.Add(BuildBackupTab());
        Controls.Add(tabs);

        var closeButton = new Button { Text = "Close", Width = 90, DialogResult = DialogResult.Cancel };
        closeButton.Left = ClientSize.Width - 16 - closeButton.Width;
        closeButton.Top = 570;
        Controls.Add(closeButton);
        CancelButton = closeButton;

        _actionsList.Format += ActionsList_Format;
        _snippetsList.Format += SnippetsList_Format;

        RefreshActionsList();
        RefreshSnippetsList();
    }

    private TabPage BuildConnectionTab()
    {
        var page = new TabPage("Connection");

        page.Controls.Add(new Label { Text = "API Key", Left = 16, Top = 16, AutoSize = true });
        _apiKeyField.Left = 16;
        _apiKeyField.Top = 36;
        _apiKeyField.Text = SettingsStore.GetApiKey() ?? "";
        page.Controls.Add(_apiKeyField);

        _showKeyCheckBox.Left = 16;
        _showKeyCheckBox.Top = 64;
        _showKeyCheckBox.CheckedChanged += (_, _) => _apiKeyField.UseSystemPasswordChar = !_showKeyCheckBox.Checked;
        page.Controls.Add(_showKeyCheckBox);

        page.Controls.Add(new Label { Text = "API Base URL", Left = 16, Top = 100, AutoSize = true });
        _baseUrlField.Left = 16;
        _baseUrlField.Top = 120;
        _baseUrlField.Text = SettingsStore.BaseUrl;
        page.Controls.Add(_baseUrlField);

        page.Controls.Add(new Label
        {
            Text = "Defaults to Salesforce's internal LLM Gateway Express. Point this at plain OpenAI or anything else that speaks the same API shape if needed.",
            Left = 16,
            Top = 148,
            AutoSize = true,
            MaximumSize = new Size(420, 0),
            ForeColor = Color.DimGray
        });

        page.Controls.Add(new Label
        {
            Text = "If this Gateway is slow to respond, WSNH waits up to 25 seconds before giving up and showing an error -- a balloon tip from the tray icon lets you know a request is running, so it's never silent.",
            Left = 16,
            Top = 196,
            AutoSize = true,
            MaximumSize = new Size(420, 0),
            ForeColor = Color.DimGray
        });

        var saveButton = new Button { Text = "Save Connection Settings", Left = 16, Top = 260, Width = 200 };
        saveButton.Click += (_, _) =>
        {
            SettingsStore.SetApiKey(_apiKeyField.Text);
            SettingsStore.BaseUrl = _baseUrlField.Text;
            MessageBox.Show(this, "Saved.", "WSNH", MessageBoxButtons.OK, MessageBoxIcon.Information);
        };
        page.Controls.Add(saveButton);

        return page;
    }

    private TabPage BuildActionsTab()
    {
        var page = new TabPage("Prompt Actions");

        _actionsList.Left = 16;
        _actionsList.Top = 16;
        page.Controls.Add(_actionsList);

        var addButton = new Button { Text = "Add", Left = 16, Top = 244, Width = 90 };
        var editButton = new Button { Text = "Edit", Left = 112, Top = 244, Width = 90 };
        var deleteButton = new Button { Text = "Delete", Left = 208, Top = 244, Width = 90 };

        addButton.Click += (_, _) =>
        {
            var newAction = new PromptAction { Name = "New Action" };
            using var editor = new PromptEditorForm(newAction, isNew: true);
            editor.ShowDialog(this);
            RefreshActionsList();
        };
        editButton.Click += (_, _) =>
        {
            if (_actionsList.SelectedItem is not PromptAction selected) return;
            using var editor = new PromptEditorForm(selected, isNew: false);
            editor.ShowDialog(this);
            RefreshActionsList();
        };
        deleteButton.Click += (_, _) =>
        {
            if (_actionsList.SelectedItem is not PromptAction selected) return;
            HotKeyManager.Shared.Unregister(selected.Id);
            PromptStore.Shared.Remove(selected);
            RefreshActionsList();
        };

        page.Controls.Add(addButton);
        page.Controls.Add(editButton);
        page.Controls.Add(deleteButton);
        return page;
    }

    private TabPage BuildSnippetsTab()
    {
        var page = new TabPage("Snippets");

        _snippetsList.Left = 16;
        _snippetsList.Top = 16;
        page.Controls.Add(_snippetsList);

        var addButton = new Button { Text = "Add Snippet", Left = 16, Top = 244, Width = 110 };
        var editButton = new Button { Text = "Edit", Left = 132, Top = 244, Width = 90 };
        var deleteButton = new Button { Text = "Delete", Left = 228, Top = 244, Width = 90 };

        addButton.Click += (_, _) =>
        {
            using var editor = new SnippetEditorForm(Snippet.Empty(), isNew: true);
            editor.ShowDialog(this);
            RefreshSnippetsList();
        };
        editButton.Click += (_, _) =>
        {
            if (_snippetsList.SelectedItem is not Snippet selected) return;
            using var editor = new SnippetEditorForm(selected, isNew: false);
            editor.ShowDialog(this);
            RefreshSnippetsList();
        };
        deleteButton.Click += (_, _) =>
        {
            if (_snippetsList.SelectedItem is not Snippet selected) return;
            SnippetHotKeyManager.Shared.Unregister(selected.Id);
            SnippetStore.Shared.Remove(selected);
            TypedTriggerWatcher.Shared.ReloadShortcuts(SnippetStore.Shared.Snippets);
            RefreshSnippetsList();
        };

        page.Controls.Add(addButton);
        page.Controls.Add(editButton);
        page.Controls.Add(deleteButton);
        return page;
    }

    private TabPage BuildBackupTab()
    {
        var page = new TabPage("Backup");

        page.Controls.Add(new Label
        {
            Text = "Export everything (API key, base URL, prompt actions, and snippets) to a file, or restore from one you exported earlier.",
            Left = 16,
            Top = 16,
            AutoSize = true,
            MaximumSize = new Size(440, 0)
        });

        var exportButton = new Button { Text = "Export Backup…", Left = 16, Top = 80, Width = 160 };
        exportButton.Click += (_, _) => ExportBackup();
        page.Controls.Add(exportButton);

        var importButton = new Button { Text = "Restore Backup…", Left = 190, Top = 80, Width = 160 };
        importButton.Click += (_, _) => ImportBackup();
        page.Controls.Add(importButton);

        return page;
    }

    private void ExportBackup()
    {
        using var dialog = new SaveFileDialog { Filter = "WSNH Backup (*.json)|*.json", FileName = "wsnh-backup.json" };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;

        File.WriteAllText(dialog.FileName, BackupManager.ExportData());
        MessageBox.Show(this, "Backup saved.", "WSNH", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private void ImportBackup()
    {
        using var dialog = new OpenFileDialog { Filter = "WSNH Backup (*.json)|*.json" };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;

        try
        {
            var json = File.ReadAllText(dialog.FileName);
            var payload = BackupManager.Restore(json);

            _apiKeyField.Text = SettingsStore.GetApiKey() ?? "";
            _baseUrlField.Text = SettingsStore.BaseUrl;
            RefreshActionsList();
            RefreshSnippetsList();

            var message = "Backup restored.";
            if (!string.Equals(payload.Platform, "windows", StringComparison.OrdinalIgnoreCase))
            {
                message += " This backup was made on Mac, so hotkeys didn't carry over (they don't translate between platforms) -- your prompts and snippets are all there, just re-set their hotkeys.";
            }
            MessageBox.Show(this, message, "WSNH", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (BackupException ex)
        {
            MessageBox.Show(this, ex.Message, "WSNH", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void RefreshActionsList()
    {
        _actionsList.Items.Clear();
        foreach (var action in PromptStore.Shared.Actions)
        {
            _actionsList.Items.Add(action);
        }
    }

    private void ActionsList_Format(object? sender, ListControlConvertEventArgs e)
    {
        if (e.ListItem is PromptAction action)
        {
            e.Value = $"{action.Name} — {action.HotKeyDisplayString}";
        }
    }

    private void RefreshSnippetsList()
    {
        _snippetsList.Items.Clear();
        foreach (var snippet in SnippetStore.Shared.Snippets)
        {
            _snippetsList.Items.Add(snippet);
        }
    }

    private void SnippetsList_Format(object? sender, ListControlConvertEventArgs e)
    {
        if (e.ListItem is Snippet snippet)
        {
            e.Value = $"{snippet.Name} — {snippet.TriggerSummary()}";
        }
    }
}
