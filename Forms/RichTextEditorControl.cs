using System.Drawing;
using System.Windows.Forms;

namespace WSNH.Forms;

/// <summary>
/// A small rich-text editor (bold/italic/underline/links) for authoring
/// Snippet content, backed by a RichTextBox. Keeps both an RTF blob (the
/// source of truth for formatting) and a plain-text fallback in sync.
/// </summary>
public class RichTextEditorControl : UserControl
{
    private readonly RichTextBox _textBox = new();
    private readonly Button _boldButton = new() { Text = "B", Font = new Font("Segoe UI", 9, FontStyle.Bold), Width = 32 };
    private readonly Button _italicButton = new() { Text = "I", Font = new Font("Segoe UI", 9, FontStyle.Italic), Width = 32 };
    private readonly Button _underlineButton = new() { Text = "U", Font = new Font("Segoe UI", 9, FontStyle.Underline), Width = 32 };
    private readonly Button _linkButton = new() { Text = "Link", Width = 48 };
    private readonly Label _hintLabel = new() { AutoSize = false, ForeColor = Color.Gray, Height = 32, Dock = DockStyle.Bottom };

    public event Action? ContentChanged;

    public RichTextEditorControl()
    {
        Height = 260;

        var toolbar = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 34,
            FlowDirection = FlowDirection.LeftToRight
        };
        toolbar.Controls.AddRange(new Control[] { _boldButton, _italicButton, _underlineButton, _linkButton });

        _textBox.Dock = DockStyle.Fill;
        _textBox.BorderStyle = BorderStyle.FixedSingle;
        _textBox.AcceptsTab = true;

        _hintLabel.Text = "To format text (bold, links, etc.): click and drag over some text below to highlight it first — the buttons above light up once something's selected.";
        _hintLabel.TextAlign = ContentAlignment.MiddleLeft;

        Controls.Add(_textBox);
        Controls.Add(_hintLabel);
        Controls.Add(toolbar);

        _boldButton.Click += (_, _) => ToggleStyle(FontStyle.Bold);
        _italicButton.Click += (_, _) => ToggleStyle(FontStyle.Italic);
        _underlineButton.Click += (_, _) => ToggleStyle(FontStyle.Underline);
        _linkButton.Click += (_, _) => InsertLink();

        _textBox.SelectionChanged += (_, _) => UpdateToolbarState();
        _textBox.TextChanged += (_, _) => ContentChanged?.Invoke();

        UpdateToolbarState();
    }

    public string Rtf
    {
        get => _textBox.Rtf;
        set
        {
            try { _textBox.Rtf = value; }
            catch { _textBox.Text = ""; }
        }
    }

    public string PlainText => _textBox.Text;

    private void UpdateToolbarState()
    {
        var hasSelection = _textBox.SelectionLength > 0;
        _boldButton.Enabled = hasSelection;
        _italicButton.Enabled = hasSelection;
        _underlineButton.Enabled = hasSelection;
        _linkButton.Enabled = hasSelection;
        _hintLabel.Text = hasSelection
            ? "Now click a button above to format the highlighted text."
            : "To format text (bold, links, etc.): click and drag over some text below to highlight it first — the buttons above light up once something's selected.";
    }

    private void ToggleStyle(FontStyle style)
    {
        if (_textBox.SelectionLength == 0) return;
        var currentFont = _textBox.SelectionFont ?? _textBox.Font;
        var hasStyle = currentFont.Style.HasFlag(style);
        var newStyle = hasStyle ? currentFont.Style & ~style : currentFont.Style | style;
        _textBox.SelectionFont = new Font(currentFont, newStyle);
        ContentChanged?.Invoke();
    }

    private void InsertLink()
    {
        if (_textBox.SelectionLength == 0) return;
        var selectedText = _textBox.SelectedText;

        using var dialog = new LinkInputDialog();
        if (dialog.ShowDialog(FindForm()) != DialogResult.OK) return;

        var url = dialog.Url.Trim();
        if (url.Length == 0) return;

        var rtfFragment = "{\\rtf1\\ansi " +
            "{\\field{\\*\\fldinst{HYPERLINK \"" + EscapeRtf(url) + "\"}}" +
            "{\\fldrslt{\\ul\\cf1 " + EscapeRtf(selectedText) + "}}}}";

        _textBox.SelectedRtf = rtfFragment;
        ContentChanged?.Invoke();
    }

    private static string EscapeRtf(string text) =>
        text.Replace("\\", "\\\\").Replace("{", "\\{").Replace("}", "\\}");
}

/// <summary>Small "enter a URL" prompt, shown as a sheet-like modal owned by the snippet editor's own window (so it can never appear on a different monitor than the window you're looking at).</summary>
internal class LinkInputDialog : Form
{
    public string Url => _input.Text;

    private readonly TextBox _input = new() { Text = "https://", Width = 280 };

    public LinkInputDialog()
    {
        Text = "Add Link";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(320, 110);

        var label = new Label { Text = "Enter the URL for the selected text.", AutoSize = true, Left = 16, Top = 16 };
        _input.Left = 16;
        _input.Top = 40;

        var addButton = new Button { Text = "Add", DialogResult = DialogResult.OK, Left = 140, Top = 72, Width = 80 };
        var cancelButton = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Left = 224, Top = 72, Width = 80 };

        Controls.AddRange(new Control[] { label, _input, addButton, cancelButton });
        AcceptButton = addButton;
        CancelButton = cancelButton;
    }
}
