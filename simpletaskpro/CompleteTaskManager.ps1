#!/usr/bin/env pwsh
# CompleteTaskManager.ps1 - Full-featured task manager with time tracking, commands, and Excel
# Single-write rendering, no cursor repositioning, embedded C# with GapBuffer text editor

param(
    [string]$Mode = "tasks",  # tasks, time, commands, excel
    [string]$Command = ""
)

# Complete embedded C# implementation
$CompleteManagerSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Linq;
using System.Text;
using System.Globalization;
using System.Diagnostics;

// ==================== DATA MODELS ====================

public class SimpleTask {
    public string Title { get; set; } = "";
    public bool Completed { get; set; } = false;
    public DateTime CreatedDate { get; set; } = DateTime.Now;
    public DateTime? DueDate { get; set; }
    public string Priority { get; set; } = "Medium";
    public List<string> Tags { get; set; } = new List<string>();
    public string Notes { get; set; } = "";
    public string ID1 { get; set; } = "";
    public string ID2 { get; set; } = "";
    public string ParentId { get; set; } = "";
    public List<SimpleTask> Subtasks { get; set; } = new List<SimpleTask>();
    public bool SubtasksCollapsed { get; set; } = false;
    public int SortOrder { get; set; } = 0;
    
    // Display properties
    public string DisplayTitle => string.IsNullOrEmpty(Title) ? "[No Title]" : Title;
    public string StatusIcon => Completed ? "■" : "☐";
    public string PriorityIcon => Priority switch {
        "High" => "H",
        "Medium" => "M", 
        "Low" => "L",
        _ => " "
    };
    
    public bool IsParent() => string.IsNullOrEmpty(ParentId);
}

public class TimeEntry {
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Description { get; set; } = "";
    public string ID1Display { get; set; } = "";
    public string WeekEndingFriday { get; set; } = "";
    public double Monday { get; set; } = 0.0;
    public double Tuesday { get; set; } = 0.0;
    public double Wednesday { get; set; } = 0.0;
    public double Thursday { get; set; } = 0.0;
    public double Friday { get; set; } = 0.0;
    public double Saturday { get; set; } = 0.0;
    public double Sunday { get; set; } = 0.0;
    public string Modified { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
    public string Created { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
    public bool IsProjectEntry { get; set; } = false;
    public string ProjectCode { get; set; } = "";
    public string FiscalYear { get; set; } = "";
    public double Total { get; set; } = 0.0;
    
    public double TotalHours => Monday + Tuesday + Wednesday + Thursday + Friday + Saturday + Sunday;
}

public class Command {
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Title { get; set; } = "";
    public string CommandText { get; set; } = "";
    public string Description { get; set; } = "";
    public string GroupId { get; set; } = "";
    public bool CommandsCollapsed { get; set; } = false;
    public int SortOrder { get; set; } = 0;
    public List<string> Tags { get; set; } = new List<string>();
}

// ==================== GAP BUFFER TEXT EDITOR ====================

public class GapBuffer {
    private char[] buffer;
    private int gapStart;
    private int gapEnd;
    private const int InitialSize = 1024;
    
    public GapBuffer() {
        buffer = new char[InitialSize];
        gapStart = 0;
        gapEnd = InitialSize;
    }
    
    public void Insert(char c) {
        if (gapStart == gapEnd) ExpandGap();
        buffer[gapStart++] = c;
    }
    
    public void Insert(string text) {
        foreach (char c in text) Insert(c);
    }
    
    public bool Delete() {
        if (gapStart > 0) {
            gapStart--;
            return true;
        }
        return false;
    }
    
    public void MoveCursor(int offset) {
        if (offset < 0) {
            // Move left
            for (int i = 0; i < -offset && gapStart > 0; i++) {
                buffer[--gapEnd] = buffer[--gapStart];
            }
        } else {
            // Move right  
            for (int i = 0; i < offset && gapEnd < buffer.Length; i++) {
                buffer[gapStart++] = buffer[gapEnd++];
            }
        }
    }
    
    private void ExpandGap() {
        int newSize = buffer.Length * 2;
        char[] newBuffer = new char[newSize];
        
        Array.Copy(buffer, 0, newBuffer, 0, gapStart);
        Array.Copy(buffer, gapEnd, newBuffer, newSize - (buffer.Length - gapEnd), buffer.Length - gapEnd);
        
        gapEnd = newSize - (buffer.Length - gapEnd);
        buffer = newBuffer;
    }
    
    public override string ToString() {
        var sb = new StringBuilder();
        for (int i = 0; i < gapStart; i++) sb.Append(buffer[i]);
        for (int i = gapEnd; i < buffer.Length; i++) sb.Append(buffer[i]);
        return sb.ToString();
    }
}

// ==================== EFFICIENT SINGLE-WRITE RENDERER ====================

public static class ScreenRenderer {
    private static StringBuilder screenBuffer = new StringBuilder(8192);
    
    public static void Clear() {
        screenBuffer.Clear();
        screenBuffer.Append("\x1b[2J\x1b[H\x1b[?25l"); // Clear, home, hide cursor
    }
    
    public static void WriteLine(string text = "", ConsoleColor color = ConsoleColor.White) {
        if (color != ConsoleColor.White) {
            screenBuffer.Append($"\x1b[{GetColorCode(color)}m");
        }
        screenBuffer.AppendLine(text);
        if (color != ConsoleColor.White) {
            screenBuffer.Append("\x1b[0m"); // Reset
        }
    }
    
    public static void Write(string text, ConsoleColor color = ConsoleColor.White) {
        if (color != ConsoleColor.White) {
            screenBuffer.Append($"\x1b[{GetColorCode(color)}m");
        }
        screenBuffer.Append(text);
        if (color != ConsoleColor.White) {
            screenBuffer.Append("\x1b[0m");
        }
    }
    
    public static void SetPosition(int x, int y) {
        screenBuffer.Append($"\x1b[{y + 1};{x + 1}H");
    }
    
    public static void Render() {
        screenBuffer.Append("\x1b[?25h"); // Show cursor
        Console.Write(screenBuffer.ToString());
        screenBuffer.Clear();
    }
    
    private static string GetColorCode(ConsoleColor color) => color switch {
        ConsoleColor.Red => "31",
        ConsoleColor.Green => "32", 
        ConsoleColor.Yellow => "33",
        ConsoleColor.Blue => "34",
        ConsoleColor.Magenta => "35",
        ConsoleColor.Cyan => "36",
        ConsoleColor.White => "37",
        ConsoleColor.Gray => "90",
        ConsoleColor.DarkGray => "90",
        _ => "37"
    };
}

// ==================== MAIN APPLICATION ====================

public static class CompleteTaskManager {
    private static List<SimpleTask> allTasks = new List<SimpleTask>();
    private static List<TimeEntry> timeEntries = new List<TimeEntry>();
    private static List<Command> commands = new List<Command>();
    
    private static List<SimpleTask> flatTaskList = new List<SimpleTask>();
    private static List<TimeEntry> flatTimeList = new List<TimeEntry>();
    private static List<Command> flatCommandList = new List<Command>();
    
    private static int selectedIndex = 0;
    private static string currentMode = "tasks";
    private static string statusMessage = "";
    
    // File paths
    private static readonly string tasksPath = "Data/tasks.json";
    private static readonly string timePath = "Data/timeentries.json";
    private static readonly string commandsPath = "Data/commands.json";
    
    // Notes editor
    private static GapBuffer notesBuffer = new GapBuffer();
    private static bool editingNotes = false;
    private static SimpleTask editingTask = null;
    
    public static void Main(string mode = "tasks", string command = "") {
        currentMode = mode.ToLower();
        
        LoadAllData();
        
        if (!string.IsNullOrEmpty(command)) {
            HandleCommand(command);
            return;
        }
        
        RunInteractiveMode();
    }
    
    private static void LoadAllData() {
        LoadTasks();
        LoadTimeEntries();
        LoadCommands();
    }
    
    private static void LoadTasks() {
        try {
            if (File.Exists(tasksPath)) {
                var json = File.ReadAllText(tasksPath);
                allTasks = JsonSerializer.Deserialize<List<SimpleTask>>(json) ?? new List<SimpleTask>();
            } else {
                allTasks = new List<SimpleTask>();
            }
            BuildTaskFlatList();
        } catch (Exception ex) {
            statusMessage = $"Error loading tasks: {ex.Message}";
        }
    }
    
    private static void LoadTimeEntries() {
        try {
            if (File.Exists(timePath)) {
                var json = File.ReadAllText(timePath);
                timeEntries = JsonSerializer.Deserialize<List<TimeEntry>>(json) ?? new List<TimeEntry>();
            } else {
                timeEntries = new List<TimeEntry>();
            }
            flatTimeList = timeEntries.OrderByDescending(t => t.WeekEndingFriday).ToList();
        } catch (Exception ex) {
            statusMessage = $"Error loading time entries: {ex.Message}";
        }
    }
    
    private static void LoadCommands() {
        try {
            if (File.Exists(commandsPath)) {
                var json = File.ReadAllText(commandsPath);
                commands = JsonSerializer.Deserialize<List<Command>>(json) ?? new List<Command>();
            } else {
                commands = new List<Command>();
            }
            flatCommandList = commands.OrderBy(c => c.SortOrder).ToList();
        } catch (Exception ex) {
            statusMessage = $"Error loading commands: {ex.Message}";
        }
    }
    
    private static void BuildTaskFlatList() {
        flatTaskList.Clear();
        foreach (var task in allTasks.Where(t => t.IsParent()).OrderBy(t => t.SortOrder)) {
            flatTaskList.Add(task);
            if (!task.SubtasksCollapsed) {
                flatTaskList.AddRange(task.Subtasks);
            }
        }
        
        if (selectedIndex >= flatTaskList.Count) {
            selectedIndex = Math.Max(0, flatTaskList.Count - 1);
        }
    }
    
    private static void RunInteractiveMode() {
        bool running = true;
        
        while (running) {
            if (editingNotes) {
                RenderNotesEditor();
            } else {
                switch (currentMode) {
                    case "tasks": RenderTaskView(); break;
                    case "time": RenderTimeView(); break;
                    case "commands": RenderCommandView(); break;
                    case "excel": RenderExcelView(); break;
                    default: RenderTaskView(); break;
                }
            }
            
            ScreenRenderer.Render();
            
            var key = Console.ReadKey(true);
            
            if (editingNotes) {
                if (!HandleNotesInput(key)) {
                    running = false;
                }
            } else {
                if (!HandleMainInput(key)) {
                    running = false;
                }
            }
        }
        
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine("Task Manager exited. Have a great day!", ConsoleColor.Green);
        ScreenRenderer.Render();
    }
    
    private static void RenderTaskView() {
        ScreenRenderer.Clear();
        
        // Header
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine("                     COMPLETE TASK MANAGER                        ", ConsoleColor.Cyan);  
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine();
        
        if (flatTaskList.Count == 0) {
            ScreenRenderer.WriteLine("  No tasks found. Press 'N' to create a new task.", ConsoleColor.Yellow);
        } else {
            // Column headers
            ScreenRenderer.WriteLine(" St Pri  Created      Due          Title                         ", ConsoleColor.Gray);
            ScreenRenderer.WriteLine(" ──────────────────────────────────────────────────────────────", ConsoleColor.Gray);
            
            // Tasks
            for (int i = 0; i < flatTaskList.Count; i++) {
                var task = flatTaskList[i];
                bool isSelected = (i == selectedIndex);
                bool isSubtask = !task.IsParent();
                
                var line = new StringBuilder();
                
                // Selection indicator
                line.Append(isSelected ? ">" : " ");
                
                // Status
                line.Append($" {task.StatusIcon}  ");
                
                // Priority
                line.Append($" {task.PriorityIcon}  ");
                
                // Created date
                line.Append($" {task.CreatedDate.ToString("MM-dd")}       ");
                
                // Due date
                var due = task.DueDate?.ToString("MM-dd") ?? "     ";
                line.Append($"{due}        ");
                
                // Indent for subtasks
                if (isSubtask) line.Append("  ├─ ");
                else line.Append("     ");
                
                // Title
                var title = task.DisplayTitle;
                if (title.Length > 30) title = title.Substring(0, 27) + "...";
                line.Append(title);
                
                // Tags
                if (task.Tags.Any()) {
                    line.Append($" [{string.Join(", ", task.Tags)}]");
                }
                
                var color = isSelected ? ConsoleColor.Blue : 
                           task.Completed ? ConsoleColor.DarkGreen : 
                           isSubtask ? ConsoleColor.Gray : ConsoleColor.White;
                           
                ScreenRenderer.WriteLine(line.ToString(), color);
            }
        }
        
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine($"Tasks: {flatTaskList.Count} | Selected: {selectedIndex + 1}", ConsoleColor.Gray);
        
        // Status message
        if (!string.IsNullOrEmpty(statusMessage)) {
            ScreenRenderer.WriteLine();
            ScreenRenderer.WriteLine(statusMessage, ConsoleColor.Yellow);
            statusMessage = "";
        }
        
        // Help
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine("Tasks: ↑↓:Nav | N:New | D:Del | X:Toggle | Enter:Notes | S:Save | Tab:Mode | Q:Quit", ConsoleColor.DarkCyan);
    }
    
    private static void RenderTimeView() {
        ScreenRenderer.Clear();
        
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Green);
        ScreenRenderer.WriteLine("                      TIME TRACKING                               ", ConsoleColor.Green);  
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Green);
        ScreenRenderer.WriteLine();
        
        if (flatTimeList.Count == 0) {
            ScreenRenderer.WriteLine("  No time entries found. Press 'N' to create a new entry.", ConsoleColor.Yellow);
        } else {
            ScreenRenderer.WriteLine(" Code  Description                  Week End    Total Hours", ConsoleColor.Gray);
            ScreenRenderer.WriteLine(" ─────────────────────────────────────────────────────────", ConsoleColor.Gray);
            
            for (int i = 0; i < flatTimeList.Count; i++) {
                var entry = flatTimeList[i];
                bool isSelected = (i == selectedIndex);
                
                var line = new StringBuilder();
                line.Append(isSelected ? ">" : " ");
                line.Append($" {entry.ID1Display,-5} ");
                
                var desc = entry.Description;
                if (desc.Length > 25) desc = desc.Substring(0, 22) + "...";
                line.Append($"{desc,-25} ");
                
                line.Append($"{entry.WeekEndingFriday,-10} ");
                line.Append($"{entry.TotalHours,8:F1}");
                
                var color = isSelected ? ConsoleColor.Blue : ConsoleColor.White;
                ScreenRenderer.WriteLine(line.ToString(), color);
            }
        }
        
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine("Time: ↑↓:Nav | N:New | E:Edit | D:Del | X:Export | Tab:Mode | Q:Quit", ConsoleColor.DarkCyan);
    }
    
    private static void RenderCommandView() {
        ScreenRenderer.Clear();
        
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Magenta);
        ScreenRenderer.WriteLine("                     COMMAND LIBRARY                              ", ConsoleColor.Magenta);  
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Magenta);
        ScreenRenderer.WriteLine();
        
        if (flatCommandList.Count == 0) {
            ScreenRenderer.WriteLine("  No commands found. Press 'N' to create a new command.", ConsoleColor.Yellow);
        } else {
            ScreenRenderer.WriteLine(" Title                           Description", ConsoleColor.Gray);
            ScreenRenderer.WriteLine(" ──────────────────────────────────────────────────────────", ConsoleColor.Gray);
            
            for (int i = 0; i < flatCommandList.Count; i++) {
                var cmd = flatCommandList[i];
                bool isSelected = (i == selectedIndex);
                
                var line = new StringBuilder();
                line.Append(isSelected ? ">" : " ");
                
                var title = cmd.Title;
                if (title.Length > 30) title = title.Substring(0, 27) + "...";
                line.Append($" {title,-30} ");
                
                var desc = cmd.Description;
                if (desc.Length > 30) desc = desc.Substring(0, 27) + "...";
                line.Append(desc);
                
                var color = isSelected ? ConsoleColor.Blue : ConsoleColor.White;
                ScreenRenderer.WriteLine(line.ToString(), color);
            }
        }
        
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine("Commands: ↑↓:Nav | N:New | E:Edit | D:Del | Enter:Run | Tab:Mode | Q:Quit", ConsoleColor.DarkCyan);
    }
    
    private static void RenderExcelView() {
        ScreenRenderer.Clear();
        
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Yellow);
        ScreenRenderer.WriteLine("                      EXCEL INTEGRATION                           ", ConsoleColor.Yellow);  
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Yellow);
        ScreenRenderer.WriteLine();
        
        ScreenRenderer.WriteLine("Excel Export Options:", ConsoleColor.White);
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine("  1. Export Tasks to CSV", selectedIndex == 0 ? ConsoleColor.Blue : ConsoleColor.Gray);
        ScreenRenderer.WriteLine("  2. Export Time Entries to CSV", selectedIndex == 1 ? ConsoleColor.Blue : ConsoleColor.Gray);
        ScreenRenderer.WriteLine("  3. Export Commands to CSV", selectedIndex == 2 ? ConsoleColor.Blue : ConsoleColor.Gray);
        ScreenRenderer.WriteLine("  4. Export All Data to Excel Format", selectedIndex == 3 ? ConsoleColor.Blue : ConsoleColor.Gray);
        ScreenRenderer.WriteLine();
        
        if (!string.IsNullOrEmpty(statusMessage)) {
            ScreenRenderer.WriteLine();
            ScreenRenderer.WriteLine(statusMessage, ConsoleColor.Yellow);
            statusMessage = "";
        }
        
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine("Excel: ↑↓:Nav | Enter:Export | Tab:Mode | Q:Quit", ConsoleColor.DarkCyan);
    }
    
    private static void RenderNotesEditor() {
        ScreenRenderer.Clear();
        
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine($"                   NOTES EDITOR - {editingTask?.DisplayTitle}                   ", ConsoleColor.Cyan);  
        ScreenRenderer.WriteLine("═══════════════════════════════════════════════════════════════════", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine();
        
        var notes = notesBuffer.ToString();
        var lines = notes.Split('\n');
        
        foreach (var line in lines) {
            ScreenRenderer.WriteLine(line);
        }
        
        ScreenRenderer.WriteLine();
        ScreenRenderer.WriteLine("Notes: Type to edit | Ctrl+S:Save | Escape:Cancel", ConsoleColor.DarkCyan);
    }
    
    private static bool HandleMainInput(ConsoleKeyInfo key) {
        switch (key.Key) {
            case ConsoleKey.Q:
            case ConsoleKey.Escape:
                return false;
                
            case ConsoleKey.Tab:
                CycleMode();
                break;
                
            case ConsoleKey.UpArrow:
                MoveSelection(-1);
                break;
                
            case ConsoleKey.DownArrow:
                MoveSelection(1);
                break;
                
            case ConsoleKey.N:
                CreateNew();
                break;
                
            case ConsoleKey.D:
            case ConsoleKey.Delete:
                DeleteCurrent();
                break;
                
            case ConsoleKey.S:
                SaveAll();
                break;
                
            case ConsoleKey.Enter:
                HandleEnter();
                break;
                
            case ConsoleKey.X:
                HandleSpecialAction();
                break;
                
            case ConsoleKey.E:
                EditCurrent();
                break;
        }
        
        return true;
    }
    
    private static bool HandleNotesInput(ConsoleKeyInfo key) {
        if (key.Modifiers == ConsoleModifiers.Control && key.Key == ConsoleKey.S) {
            // Save notes
            if (editingTask != null) {
                editingTask.Notes = notesBuffer.ToString();
                SaveTasks();
                statusMessage = "Notes saved!";
            }
            editingNotes = false;
            return true;
        }
        
        if (key.Key == ConsoleKey.Escape) {
            editingNotes = false;
            return true;
        }
        
        switch (key.Key) {
            case ConsoleKey.Backspace:
                notesBuffer.Delete();
                break;
            case ConsoleKey.Enter:
                notesBuffer.Insert('\n');
                break;
            case ConsoleKey.LeftArrow:
                notesBuffer.MoveCursor(-1);
                break;
            case ConsoleKey.RightArrow:
                notesBuffer.MoveCursor(1);
                break;
            default:
                if (key.KeyChar != '\0' && !char.IsControl(key.KeyChar)) {
                    notesBuffer.Insert(key.KeyChar);
                }
                break;
        }
        
        return true;
    }
    
    private static void CycleMode() {
        currentMode = currentMode switch {
            "tasks" => "time",
            "time" => "commands", 
            "commands" => "excel",
            "excel" => "tasks",
            _ => "tasks"
        };
        selectedIndex = 0;
    }
    
    private static void MoveSelection(int delta) {
        var maxIndex = currentMode switch {
            "tasks" => flatTaskList.Count - 1,
            "time" => flatTimeList.Count - 1,
            "commands" => flatCommandList.Count - 1,
            "excel" => 3,
            _ => 0
        };
        
        selectedIndex = Math.Max(0, Math.Min(maxIndex, selectedIndex + delta));
    }
    
    private static void CreateNew() {
        switch (currentMode) {
            case "tasks":
                CreateNewTask();
                break;
            case "time":
                CreateNewTimeEntry();
                break;
            case "commands":
                CreateNewCommand();
                break;
        }
    }
    
    private static void CreateNewTask() {
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine("Create New Task", ConsoleColor.Green);
        ScreenRenderer.WriteLine("═══════════════", ConsoleColor.Green);
        ScreenRenderer.WriteLine();
        ScreenRenderer.Write("Title: ");
        ScreenRenderer.Render();
        
        var title = Console.ReadLine();
        if (!string.IsNullOrWhiteSpace(title)) {
            var task = new SimpleTask { Title = title, CreatedDate = DateTime.Now };
            allTasks.Add(task);
            BuildTaskFlatList();
            SaveTasks();
            statusMessage = $"Task '{title}' created!";
        }
    }
    
    private static void CreateNewTimeEntry() {
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine("Create New Time Entry", ConsoleColor.Green);
        ScreenRenderer.WriteLine("═══════════════════", ConsoleColor.Green);
        ScreenRenderer.WriteLine();
        ScreenRenderer.Write("Description: ");
        ScreenRenderer.Render();
        
        var description = Console.ReadLine();
        if (!string.IsNullOrWhiteSpace(description)) {
            ScreenRenderer.Write("ID1 Code: ");
            ScreenRenderer.Render();
            var id1 = Console.ReadLine() ?? "";
            
            ScreenRenderer.Write("Week Ending Friday (YYYYMMDD): ");
            ScreenRenderer.Render();
            var weekEnd = Console.ReadLine() ?? DateTime.Now.ToString("yyyyMMdd");
            
            var entry = new TimeEntry { 
                Description = description,
                ID1Display = id1,
                WeekEndingFriday = weekEnd
            };
            timeEntries.Add(entry);
            flatTimeList = timeEntries.OrderByDescending(t => t.WeekEndingFriday).ToList();
            SaveTimeEntries();
            statusMessage = $"Time entry '{description}' created!";
        }
    }
    
    private static void CreateNewCommand() {
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine("Create New Command", ConsoleColor.Green);
        ScreenRenderer.WriteLine("═══════════════════", ConsoleColor.Green);
        ScreenRenderer.WriteLine();
        ScreenRenderer.Write("Title: ");
        ScreenRenderer.Render();
        
        var title = Console.ReadLine();
        if (!string.IsNullOrWhiteSpace(title)) {
            ScreenRenderer.Write("Command Text: ");
            ScreenRenderer.Render();
            var commandText = Console.ReadLine() ?? "";
            
            ScreenRenderer.Write("Description: ");
            ScreenRenderer.Render();
            var description = Console.ReadLine() ?? "";
            
            var command = new Command { 
                Title = title,
                CommandText = commandText,
                Description = description
            };
            commands.Add(command);
            flatCommandList = commands.OrderBy(c => c.SortOrder).ToList();
            SaveCommands();
            statusMessage = $"Command '{title}' created!";
        }
    }
    
    private static void DeleteCurrent() {
        switch (currentMode) {
            case "tasks":
                if (selectedIndex < flatTaskList.Count) {
                    var task = flatTaskList[selectedIndex];
                    allTasks.Remove(task);
                    BuildTaskFlatList();
                    SaveTasks();
                    statusMessage = $"Task deleted!";
                }
                break;
            case "time":
                if (selectedIndex < flatTimeList.Count) {
                    var entry = flatTimeList[selectedIndex];
                    timeEntries.Remove(entry);
                    flatTimeList = timeEntries.OrderByDescending(t => t.WeekEndingFriday).ToList();
                    SaveTimeEntries();
                    statusMessage = $"Time entry deleted!";
                }
                break;
            case "commands":
                if (selectedIndex < flatCommandList.Count) {
                    var command = flatCommandList[selectedIndex];
                    commands.Remove(command);
                    flatCommandList = commands.OrderBy(c => c.SortOrder).ToList();
                    SaveCommands();
                    statusMessage = $"Command deleted!";
                }
                break;
        }
    }
    
    private static void HandleEnter() {
        switch (currentMode) {
            case "tasks":
                if (selectedIndex < flatTaskList.Count) {
                    editingTask = flatTaskList[selectedIndex];
                    notesBuffer = new GapBuffer();
                    notesBuffer.Insert(editingTask.Notes ?? "");
                    editingNotes = true;
                }
                break;
            case "commands":
                if (selectedIndex < flatCommandList.Count) {
                    ExecuteCommand(flatCommandList[selectedIndex]);
                }
                break;
            case "excel":
                HandleExcelAction();
                break;
        }
    }
    
    private static void ExecuteCommand(Command command) {
        if (string.IsNullOrWhiteSpace(command.CommandText)) {
            statusMessage = "Command has no executable text";
            return;
        }
        
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine($"Executing: {command.Title}", ConsoleColor.Yellow);
        ScreenRenderer.WriteLine($"Command: {command.CommandText}", ConsoleColor.Gray);
        ScreenRenderer.WriteLine("═══════════════════════════════════", ConsoleColor.Yellow);
        ScreenRenderer.WriteLine();
        ScreenRenderer.Render();
        
        try {
            var processInfo = new System.Diagnostics.ProcessStartInfo {
                FileName = "pwsh",
                Arguments = $"-Command \"{command.CommandText}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };
            
            using (var process = System.Diagnostics.Process.Start(processInfo)) {
                var output = process.StandardOutput.ReadToEnd();
                var error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                
                ScreenRenderer.WriteLine("Output:", ConsoleColor.Green);
                ScreenRenderer.WriteLine(output);
                
                if (!string.IsNullOrEmpty(error)) {
                    ScreenRenderer.WriteLine("Errors:", ConsoleColor.Red);
                    ScreenRenderer.WriteLine(error);
                }
                
                ScreenRenderer.WriteLine();
                ScreenRenderer.WriteLine("Press any key to continue...", ConsoleColor.DarkCyan);
                ScreenRenderer.Render();
                Console.ReadKey(true);
            }
        } catch (Exception ex) {
            statusMessage = $"Command execution failed: {ex.Message}";
        }
    }
    
    private static void HandleSpecialAction() {
        switch (currentMode) {
            case "tasks":
                if (selectedIndex < flatTaskList.Count) {
                    var task = flatTaskList[selectedIndex];
                    task.Completed = !task.Completed;
                    SaveTasks();
                    statusMessage = $"Task marked as {(task.Completed ? "completed" : "incomplete")}";
                }
                break;
            case "excel":
                HandleExcelAction();
                break;
        }
    }
    
    private static void HandleExcelAction() {
        switch (selectedIndex) {
            case 0: ExportTasksToCSV(); break;
            case 1: ExportTimeToCSV(); break;
            case 2: ExportCommandsToCSV(); break;
            case 3: ExportAllToCSV(); break;
        }
    }
    
    private static void ExportTasksToCSV() {
        try {
            var csvPath = $"tasks_export_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            var lines = new List<string>();
            
            lines.Add("Title,Status,Priority,Created,Due,Tags,Notes");
            foreach (var task in allTasks) {
                var line = $"\"{task.Title}\",{(task.Completed ? "Completed" : "Pending")},{task.Priority},{task.CreatedDate:yyyy-MM-dd},{task.DueDate?.ToString("yyyy-MM-dd") ?? ""},\"{string.Join(";", task.Tags)}\",\"{task.Notes}\"";
                lines.Add(line);
            }
            
            File.WriteAllLines(csvPath, lines);
            statusMessage = $"Tasks exported to {csvPath}";
        } catch (Exception ex) {
            statusMessage = $"Export failed: {ex.Message}";
        }
    }
    
    private static void ExportTimeToCSV() {
        try {
            var csvPath = $"time_export_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            var lines = new List<string>();
            
            lines.Add("Description,Code,WeekEnding,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday,Total");
            foreach (var entry in timeEntries) {
                var line = $"\"{entry.Description}\",{entry.ID1Display},{entry.WeekEndingFriday},{entry.Monday},{entry.Tuesday},{entry.Wednesday},{entry.Thursday},{entry.Friday},{entry.Saturday},{entry.Sunday},{entry.TotalHours}";
                lines.Add(line);
            }
            
            File.WriteAllLines(csvPath, lines);
            statusMessage = $"Time entries exported to {csvPath}";
        } catch (Exception ex) {
            statusMessage = $"Export failed: {ex.Message}";
        }
    }
    
    private static void ExportCommandsToCSV() {
        try {
            var csvPath = $"commands_export_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            var lines = new List<string>();
            
            lines.Add("Title,CommandText,Description,Tags");
            foreach (var cmd in commands) {
                var line = $"\"{cmd.Title}\",\"{cmd.CommandText}\",\"{cmd.Description}\",\"{string.Join(";", cmd.Tags)}\"";
                lines.Add(line);
            }
            
            File.WriteAllLines(csvPath, lines);
            statusMessage = $"Commands exported to {csvPath}";
        } catch (Exception ex) {
            statusMessage = $"Export failed: {ex.Message}";
        }
    }
    
    private static void ExportAllToCSV() {
        try {
            ExportTasksToCSV();
            ExportTimeToCSV();
            ExportCommandsToCSV();
            statusMessage = "All data exported to separate CSV files";
        } catch (Exception ex) {
            statusMessage = $"Export failed: {ex.Message}";
        }
    }
    
    private static void EditCurrent() {
        switch (currentMode) {
            case "time":
                if (selectedIndex < flatTimeList.Count) {
                    EditTimeEntry(flatTimeList[selectedIndex]);
                }
                break;
            case "commands":
                if (selectedIndex < flatCommandList.Count) {
                    EditCommand(flatCommandList[selectedIndex]);
                }
                break;
            default:
                statusMessage = "Edit not available in this mode";
                break;
        }
    }
    
    private static void EditTimeEntry(TimeEntry entry) {
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine($"Edit Time Entry: {entry.Description}", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine("═══════════════════════════════════", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine();
        
        ScreenRenderer.WriteLine("Enter hours for each day (0 to skip):");
        ScreenRenderer.WriteLine();
        
        ScreenRenderer.Write($"Monday [{entry.Monday}]: ");
        ScreenRenderer.Render();
        var mondayInput = Console.ReadLine();
        if (double.TryParse(mondayInput, out double monday)) entry.Monday = monday;
        
        ScreenRenderer.Write($"Tuesday [{entry.Tuesday}]: ");
        ScreenRenderer.Render();
        var tuesdayInput = Console.ReadLine();
        if (double.TryParse(tuesdayInput, out double tuesday)) entry.Tuesday = tuesday;
        
        ScreenRenderer.Write($"Wednesday [{entry.Wednesday}]: ");
        ScreenRenderer.Render();
        var wednesdayInput = Console.ReadLine();
        if (double.TryParse(wednesdayInput, out double wednesday)) entry.Wednesday = wednesday;
        
        ScreenRenderer.Write($"Thursday [{entry.Thursday}]: ");
        ScreenRenderer.Render();
        var thursdayInput = Console.ReadLine();
        if (double.TryParse(thursdayInput, out double thursday)) entry.Thursday = thursday;
        
        ScreenRenderer.Write($"Friday [{entry.Friday}]: ");
        ScreenRenderer.Render();
        var fridayInput = Console.ReadLine();
        if (double.TryParse(fridayInput, out double friday)) entry.Friday = friday;
        
        entry.Modified = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        SaveTimeEntries();
        statusMessage = "Time entry updated!";
    }
    
    private static void EditCommand(Command command) {
        ScreenRenderer.Clear();
        ScreenRenderer.WriteLine($"Edit Command: {command.Title}", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine("═══════════════════════════════", ConsoleColor.Cyan);
        ScreenRenderer.WriteLine();
        
        ScreenRenderer.Write($"Title [{command.Title}]: ");
        ScreenRenderer.Render();
        var title = Console.ReadLine();
        if (!string.IsNullOrWhiteSpace(title)) command.Title = title;
        
        ScreenRenderer.Write($"Command [{command.CommandText}]: ");
        ScreenRenderer.Render();
        var commandText = Console.ReadLine();
        if (commandText != null) command.CommandText = commandText;
        
        ScreenRenderer.Write($"Description [{command.Description}]: ");
        ScreenRenderer.Render();
        var description = Console.ReadLine();
        if (description != null) command.Description = description;
        
        SaveCommands();
        statusMessage = "Command updated!";
    }
    
    
    private static void SaveAll() {
        SaveTasks();
        SaveTimeEntries();
        SaveCommands();
        statusMessage = "All data saved!";
    }
    
    private static void SaveTasks() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(allTasks, options);
            Directory.CreateDirectory(Path.GetDirectoryName(tasksPath) ?? ".");
            File.WriteAllText(tasksPath, json);
        } catch (Exception ex) {
            statusMessage = $"Error saving tasks: {ex.Message}";
        }
    }
    
    private static void SaveTimeEntries() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(timeEntries, options);
            Directory.CreateDirectory(Path.GetDirectoryName(timePath) ?? ".");
            File.WriteAllText(timePath, json);
        } catch (Exception ex) {
            statusMessage = $"Error saving time entries: {ex.Message}";
        }
    }
    
    private static void SaveCommands() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(commands, options);
            Directory.CreateDirectory(Path.GetDirectoryName(commandsPath) ?? ".");
            File.WriteAllText(commandsPath, json);
        } catch (Exception ex) {
            statusMessage = $"Error saving commands: {ex.Message}";
        }
    }
    
    private static void HandleCommand(string command) {
        switch (command.ToLower()) {
            case "export":
                ExportAllToCSV();
                Console.WriteLine(statusMessage);
                break;
            default:
                Console.WriteLine($"Unknown command: {command}");
                break;
        }
    }
}
'@

Write-Host "Compiling Complete Task Manager with all features..." -ForegroundColor Yellow

try {
    Add-Type -TypeDefinition $CompleteManagerSource -Language CSharp
    
    Write-Host "✓ Compilation successful!" -ForegroundColor Green
    Write-Host "Starting Complete Task Manager..." -ForegroundColor Cyan
    Write-Host ""
    
    [CompleteTaskManager]::Main($Mode, $Command)
    
} catch {
    Write-Host "✗ Compilation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}