using System;
using System.Collections.Generic;

namespace PraxisWpf.Models
{
    public class UserPreferences
    {
        public WindowSettings Window { get; set; } = new();
        public ThemeSettings Theme { get; set; } = new();
        public EditorSettings Editor { get; set; } = new();
        public KeyboardSettings Keyboard { get; set; } = new();
        public ColumnSettings Columns { get; set; } = new();
        public GeneralSettings General { get; set; } = new();

        // Metadata
        public DateTime LastModified { get; set; } = DateTime.UtcNow;
        public string Version { get; set; } = "1.0";
    }

    public class WindowSettings
    {
        public double Width { get; set; } = 800;
        public double Height { get; set; } = 600;
        public double Left { get; set; } = -1; // -1 means center
        public double Top { get; set; } = -1;  // -1 means center
        public bool IsMaximized { get; set; } = false;
        public string Theme { get; set; } = "Cyberpunk";
    }

    public class ThemeSettings
    {
        public string CurrentTheme { get; set; } = "Cyberpunk";
        public double FontSize { get; set; } = 12;
        public string FontFamily { get; set; } = "Consolas, Courier New, monospace";
        public double WindowOpacity { get; set; } = 1.0;
        public bool EnableAnimations { get; set; } = true;
        public bool EnableGlowEffects { get; set; } = true;
    }

    public class EditorSettings
    {
        public string ExternalEditorPath { get; set; } = "";
        public string ExternalEditorArgs { get; set; } = "\"{0}\""; // {0} will be replaced with file path
        public bool UseExternalEditor { get; set; } = false;
        public bool AutoSaveOnEdit { get; set; } = true;
        public int AutoSaveIntervalSeconds { get; set; } = 30;
    }

    public class KeyboardSettings
    {
        public Dictionary<string, string> CustomShortcuts { get; set; } = new();
        public bool EnableKeyboardNavigation { get; set; } = true;
        public bool EnableVimMode { get; set; } = false;
        public int KeyRepeatDelay { get; set; } = 500;
    }

    public class ColumnSettings
    {
        public List<ColumnDefinition> Columns { get; set; } = new()
        {
            new() { Name = "Id1", Width = 40, Visible = true, Order = 0 },
            new() { Name = "Id2", Width = 100, Visible = true, Order = 1 },
            new() { Name = "AssignedDate", Width = 100, Visible = true, Order = 2 },
            new() { Name = "DueDate", Width = 100, Visible = true, Order = 3 },
            new() { Name = "Priority", Width = 20, Visible = true, Order = 4 },
            new() { Name = "Status", Width = 20, Visible = true, Order = 5 },
            new() { Name = "Name", Width = -1, Visible = true, Order = 6 } // -1 means fill remaining space
        };

        public bool AutoResizeColumns { get; set; } = true;
        public double MinColumnWidth { get; set; } = 50;
        public double MaxColumnWidth { get; set; } = 300;
    }

    public class ColumnDefinition
    {
        public string Name { get; set; } = "";
        public double Width { get; set; } = 100;
        public bool Visible { get; set; } = true;
        public int Order { get; set; } = 0;
        public bool Resizable { get; set; } = true;
        public string Header { get; set; } = "";
    }

    public class GeneralSettings
    {
        public bool ConfirmDelete { get; set; } = true;
        public bool ShowStatusBar { get; set; } = true;
        public bool ShowToolbar { get; set; } = false;
        public bool AutoExpandNewTasks { get; set; } = true;
        public bool RememberLastSelected { get; set; } = true;
        public int MaxRecentFiles { get; set; } = 10;
        public bool EnableLogging { get; set; } = true;
        public string LogLevel { get; set; } = "Info";
        public int LogRetentionDays { get; set; } = 30;
    }
}