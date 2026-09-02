using System.Drawing;
using System.Windows.Forms;
using WSNH.Models;
using WSNH.Services;

namespace WSNH.Forms;

/// <summary>Add/edit form for a single Snippet: name, hotkey, typed shortcut, and the rich text content itself.</summary>
public class SnippetEditorForm : Form
{
    private readonly Snippet _snippet;
    private readonly bool _isNew;

    private readonly TextBox _nameField = new() { Width = 300 };
    private readonly HotKeyRecorderControl _hotKeyRecorder = new();
    private readonly TextBox _shortcutField = new() { Width = 220, BorderStyle = BorderStyle.FixedSingle };
    private readonly RichTextEditorControl _contentEditor = new() { Width = 460, Height = 240 };
    private readonly Label _reasonLabel = new() { AutoSize = true, ForeColor = Color.DimGray };
    private readonly Button _saveButton = new() { Text = "Save", Width = 90 };

    public SnippetEditorForm(Snippet snippet, bool isNew)
    {
        _snippet = snippet;
        _isNew = isNew;

        Text = isNew ? "New Snippet" : "Edit Snippet";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(520, 480);

        BuildLayout();
        LoadFromSnippet();
        UpdateSaveState();
    }

    private void BuildLayout()
    {
        var y = 16;

        Controls.Add(new Label { Text = "Name", Left = 16, Top = y, AutoSize = true });
        _nameField.Left = 16;
        _nameField.Top = y + 20;
        Controls.Add(_nameField);
        y += 56;

        Controls.Add(new Label { Text = "Hotkey (optional)", Left = 16, Top = y, AutoSize = true });
        _hotKeyRecorder.Left = 16;
        _hotKeyRecorder.Top = y + 20;
        Controls.Add(_hotKeyRecorder);
        y += 64;

        Controls.Add(new Label
        {
            Text = "Typed shortcut (optional) — type this anywhere, then press Space/Tab/Enter to expand it",
            Left = 16,
            Top = y,
            AutoSize = true,
            MaximumSize = new Size(480, 0)
        });
        _shortcutField.Left = 16;
        _shortcutField.Top = y + 32;
        Controls.Add(_shortcutField);
        y += 68;

        Controls.Add(new Label { Text = "Content", Left = 16, Top = y, AutoSize = true });
        _contentEditor.Left = 16;
        _contentEditor.Top = y + 20;
        Controls.Add(_contentEditor);
        y += 20 + _contentEditor.Height + 12;

        _reasonLabel.Left = 16;
        _reasonLabel.Top = y;
        Controls.Add(_reasonLabel);
        y += 24;

        var cancelButton = new Button { Text = "Cancel", Width = 90, DialogResult = DialogResult.Cancel };
        cancelButton.Left = ClientSize.Width - 16 - cancelButton.Width - 8 - _saveButton.Width;
        cancelButton.Top = y;
        Controls.Add(cancelButton);

        _saveButton.Left = ClientSize.Width - 16 - _saveButton.Width;
        _saveButton.Top = y;
        _saveButton.Click += OnSave;
        Controls.Add(_saveButton);

        CancelButton = cancelButton;

        _nameField.TextChanged += (_, _) => UpdateSaveState();
        _hotKeyRecorder.ValueChanged += UpdateSaveState;
        _shortcutField.TextChanged += (_, _) => UpdateSaveState();
        Shown += (_, _) => UpdateSaveState();
    }

    private void LoadFromSnippet()
    {
        _nameField.Text = _snippet.Name;
        _hotKeyRecorder.SetValue(_snippet.KeyCode, _snippet.ModifierFlags);
        _shortcutField.Text = _snippet.Shortcut;
        _contentEditor.Rtf = _snippet.Rtf;
    }

    private void UpdateSaveState()
    {
        var hasHotkey = _hotKeyRecorder.KeyCode != 0 && _hotKeyRecorder.ModifierFlags != 0;
        var hasShortcut = !string.IsNullOrWhiteSpace(_shortcutField.Text);

        string reason;
        if (string.IsNullOrWhiteSpace(_nameField.Text))
        {
            reason = "Add a name before saving.";
        }
        else if (!hasHotkey && !hasShortcut)
        {
            reason = "Add a hotkey, a typed shortcut, or both before saving.";
        }
        else
        {
            reason = "";
        }

        _reasonLabel.Text = reason;
        _saveButton.Enabled = reason.Length == 0;
    }

    private void OnSave(object? sender, EventArgs e)
    {
        // The hotkey recorder polls live, but the Save button's enabled
        // state is only driven by explicit change events -- re-check right
        // before saving in case a hotkey was just captured.
        UpdateSaveState();
        if (!_saveButton.Enabled) return;

        _snippet.Name = _nameField.Text.Trim();
        _snippet.KeyCode = _hotKeyRecorder.KeyCode;
        _snippet.ModifierFlags = _hotKeyRecorder.ModifierFlags;
        _snippet.Shortcut = _shortcutField.Text.Trim();
        _snippet.Rtf = _contentEditor.Rtf;
        _snippet.PlainText = _contentEditor.PlainText;

        if (_isNew)
        {
            SnippetStore.Shared.Add(_snippet);
        }
        else
        {
            SnippetStore.Shared.Update(_snippet);
        }

        SnippetHotKeyManager.Shared.RegisterAll(SnippetStore.Shared.Snippets);
        TypedTriggerWatcher.Shared.ReloadShortcuts(SnippetStore.Shared.Snippets);

        DialogResult = DialogResult.OK;
        Close();
    }
}
