using System.Drawing;
using System.Windows.Forms;
using WSNH.Models;
using WSNH.Services;

namespace WSNH.Forms;

/// <summary>Add/edit form for a single Prompt Action: name, hotkey, model, prompt template, and output mode.</summary>
public class PromptEditorForm : Form
{
    private readonly PromptAction _action;
    private readonly bool _isNew;

    private readonly TextBox _nameField = new() { Width = 300 };
    private readonly HotKeyRecorderControl _hotKeyRecorder = new();
    private readonly TextBox _modelField = new() { Width = 300 };
    private readonly TextBox _templateField = new() { Width = 460, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical, AcceptsTab = true };
    private readonly ComboBox _outputModeCombo = new() { Width = 200, DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly Label _reasonLabel = new() { AutoSize = true, ForeColor = Color.DimGray };
    private readonly Button _saveButton = new() { Text = "Save", Width = 90 };

    public PromptEditorForm(PromptAction action, bool isNew)
    {
        _action = action;
        _isNew = isNew;

        Text = isNew ? "New Prompt Action" : "Edit Prompt Action";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(520, 460);

        _outputModeCombo.Items.AddRange(new object[] { "Auto-paste (replace selection)", "Popup window", "Ask each time" });

        BuildLayout();
        LoadFromAction();
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

        Controls.Add(new Label { Text = "Hotkey", Left = 16, Top = y, AutoSize = true });
        _hotKeyRecorder.Left = 16;
        _hotKeyRecorder.Top = y + 20;
        Controls.Add(_hotKeyRecorder);
        y += 64;

        Controls.Add(new Label { Text = "Model", Left = 16, Top = y, AutoSize = true });
        _modelField.Left = 16;
        _modelField.Top = y + 20;
        Controls.Add(_modelField);
        y += 56;

        Controls.Add(new Label { Text = "What happens to the result", Left = 16, Top = y, AutoSize = true });
        _outputModeCombo.Left = 16;
        _outputModeCombo.Top = y + 20;
        Controls.Add(_outputModeCombo);
        y += 56;

        Controls.Add(new Label { Text = "Prompt template (use {selectedText} where the selected text should go)", Left = 16, Top = y, AutoSize = true, MaximumSize = new Size(480, 0) });
        _templateField.Left = 16;
        _templateField.Top = y + 32;
        Controls.Add(_templateField);
        y += 32 + _templateField.Height + 12;

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
        _modelField.TextChanged += (_, _) => UpdateSaveState();
        _templateField.TextChanged += (_, _) => UpdateSaveState();
    }

    private void LoadFromAction()
    {
        _nameField.Text = _action.Name;
        _hotKeyRecorder.SetValue(_action.KeyCode, _action.ModifierFlags);
        _modelField.Text = _action.Model;
        _templateField.Text = _action.PromptTemplate;
        _outputModeCombo.SelectedIndex = (int)_action.OutputMode;
    }

    private void UpdateSaveState()
    {
        var hasHotkey = _hotKeyRecorder.KeyCode != 0 && _hotKeyRecorder.ModifierFlags != 0;

        string reason;
        if (string.IsNullOrWhiteSpace(_nameField.Text))
        {
            reason = "Add a name before saving.";
        }
        else if (!hasHotkey)
        {
            reason = "Set a hotkey before saving.";
        }
        else if (string.IsNullOrWhiteSpace(_modelField.Text))
        {
            reason = "Add a model name before saving.";
        }
        else if (string.IsNullOrWhiteSpace(_templateField.Text))
        {
            reason = "Add a prompt template before saving.";
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
        UpdateSaveState();
        if (!_saveButton.Enabled) return;

        _action.Name = _nameField.Text.Trim();
        _action.KeyCode = _hotKeyRecorder.KeyCode;
        _action.ModifierFlags = _hotKeyRecorder.ModifierFlags;
        _action.Model = _modelField.Text.Trim();
        _action.PromptTemplate = _templateField.Text;
        _action.OutputMode = (OutputMode)_outputModeCombo.SelectedIndex;

        if (_isNew)
        {
            PromptStore.Shared.Add(_action);
        }
        else
        {
            PromptStore.Shared.Update(_action);
        }

        HotKeyManager.Shared.RegisterAll(PromptStore.Shared.Actions);

        DialogResult = DialogResult.OK;
        Close();
    }
}
