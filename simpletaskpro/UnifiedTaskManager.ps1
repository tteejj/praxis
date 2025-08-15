#!/usr/bin/env pwsh
# UnifiedTaskManager.ps1 - Complete business logic port with full function parity
# Preserves ALL functionality from existing screens without UI dependencies

param(
    [string]$Mode = "tasks",
    [string]$Command = "",
    [switch]$Interactive = $false
)

# Embedded C# with complete business logic implementation
$UnifiedManagerSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Linq;
using System.Text;
using System.Globalization;
using System.Diagnostics;

// ==================== COMPLETE DATA MODELS ====================

public class SimpleTask {
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Title { get; set; } = "";
    public bool Completed { get; set; } = false;
    public DateTime CreatedDate { get; set; } = DateTime.Now;
    public DateTime ModifiedDate { get; set; } = DateTime.Now;
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
    
    // Business logic methods
    public void SetTimeForDay(string day, double hours) {
        switch (day.ToLower()) {
            case "monday": Monday = hours; break;
            case "tuesday": Tuesday = hours; break;
            case "wednesday": Wednesday = hours; break;
            case "thursday": Thursday = hours; break;
            case "friday": Friday = hours; break;
            case "saturday": Saturday = hours; break;
            case "sunday": Sunday = hours; break;
        }
        Modified = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
    }
    
    public double GetTimeForDay(string day) {
        return day.ToLower() switch {
            "monday" => Monday,
            "tuesday" => Tuesday,
            "wednesday" => Wednesday,
            "thursday" => Thursday,
            "friday" => Friday,
            "saturday" => Saturday,
            "sunday" => Sunday,
            _ => 0.0
        };
    }
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
    public List<Command> Commands { get; set; } = new List<Command>();
    public DateTime CreatedDate { get; set; } = DateTime.Now;
    public DateTime ModifiedDate { get; set; } = DateTime.Now;
    
    public bool IsGroup() => string.IsNullOrEmpty(GroupId) && Commands.Any();
    public bool IsCommand() => !string.IsNullOrEmpty(CommandText);
}

public class ExcelMapping {
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string DisplayName { get; set; } = "";
    public string SourceCell { get; set; } = "";
    public string DestinationCell { get; set; } = "";
    public string T2020Name { get; set; } = "";
    public string Category { get; set; } = "";
    public bool IncludeInT2020 { get; set; } = true;
    public int SortOrder { get; set; } = 0;
}

// ==================== BUSINESS LOGIC SERVICES ====================

public static class TaskManager {
    private static List<SimpleTask> allTasks = new List<SimpleTask>();
    private static List<TimeEntry> timeEntries = new List<TimeEntry>();
    private static List<Command> commands = new List<Command>();
    private static List<ExcelMapping> excelMappings = new List<ExcelMapping>();
    
    // Current state
    private static string currentMode = "tasks";
    private static int selectedIndex = 0;
    private static string currentFilter = "All";
    private static string searchTerm = "";
    private static bool showCompletedTasks = true;
    
    // File paths
    private static readonly string tasksPath = "Data/tasks.json";
    private static readonly string timePath = "Data/timeentries.json";
    private static readonly string commandsPath = "Data/commands.json";
    private static readonly string excelMappingsPath = "Data/excelmappings.json";
    
    // ==================== CORE INITIALIZATION ====================
    
    public static void Initialize() {
        LoadAllData();
    }
    
    private static void LoadAllData() {
        LoadTasks();
        LoadTimeEntries();
        LoadCommands();
        LoadExcelMappings();
    }
    
    // ==================== TASK MANAGEMENT BUSINESS LOGIC ====================
    
    private static void LoadTasks() {
        try {
            if (File.Exists(tasksPath)) {
                var json = File.ReadAllText(tasksPath);
                allTasks = JsonSerializer.Deserialize<List<SimpleTask>>(json) ?? new List<SimpleTask>();
            } else {
                CreateSampleTasks();
            }
        } catch (Exception ex) {
            Console.WriteLine($"Error loading tasks: {ex.Message}");
            CreateSampleTasks();
        }
    }
    
    private static void CreateSampleTasks() {
        allTasks = new List<SimpleTask> {
            new SimpleTask { 
                Title = "Review code changes", 
                Priority = "High",
                CreatedDate = DateTime.Now.AddDays(-2),
                DueDate = DateTime.Now.AddDays(1),
                Tags = new List<string> { "review", "urgent" }
            },
            new SimpleTask { 
                Title = "Update documentation", 
                Priority = "Medium",
                CreatedDate = DateTime.Now.AddDays(-1),
                Tags = new List<string> { "docs", "maintenance" }
            }
        };
    }
    
    // Task CRUD Operations (from TaskListScreen)
    public static void CreateNewTask(string title = "New Task", string priority = "Medium") {
        var task = new SimpleTask {
            Title = title,
            Priority = priority,
            CreatedDate = DateTime.Now
        };
        allTasks.Add(task);
        SaveTasks();
    }
    
    public static void CreateNewSubtask(string parentId, string title = "New Subtask") {
        var parent = allTasks.FirstOrDefault(t => t.Id == parentId);
        if (parent != null) {
            var subtask = new SimpleTask {
                Title = title,
                ParentId = parentId,
                CreatedDate = DateTime.Now
            };
            parent.Subtasks.Add(subtask);
            SaveTasks();
        }
    }
    
    public static void DeleteTask(string taskId) {
        var task = allTasks.FirstOrDefault(t => t.Id == taskId);
        if (task != null) {
            allTasks.Remove(task);
            SaveTasks();
        }
        
        // Also remove from parent subtasks
        foreach (var parent in allTasks) {
            parent.Subtasks.RemoveAll(st => st.Id == taskId);
        }
    }
    
    public static void ToggleTaskComplete(string taskId) {
        var task = FindTaskById(taskId);
        if (task != null) {
            task.Completed = !task.Completed;
            task.ModifiedDate = DateTime.Now;
            SaveTasks();
        }
    }
    
    public static void UpdateTaskField(string taskId, string field, string value) {
        var task = FindTaskById(taskId);
        if (task == null) return;
        
        switch (field.ToLower()) {
            case "title": task.Title = value; break;
            case "priority": task.Priority = value; break;
            case "notes": task.Notes = value; break;
            case "id1": task.ID1 = value; break;
            case "id2": task.ID2 = value; break;
            case "tags": 
                task.Tags = value.Split(',', StringSplitOptions.RemoveEmptyEntries)
                               .Select(t => t.Trim()).ToList();
                break;
        }
        task.ModifiedDate = DateTime.Now;
        SaveTasks();
    }
    
    public static void SetTaskDueDate(string taskId, DateTime? dueDate) {
        var task = FindTaskById(taskId);
        if (task != null) {
            task.DueDate = dueDate;
            task.ModifiedDate = DateTime.Now;
            SaveTasks();
        }
    }
    
    private static SimpleTask FindTaskById(string taskId) {
        var task = allTasks.FirstOrDefault(t => t.Id == taskId);
        if (task != null) return task;
        
        // Search in subtasks
        foreach (var parent in allTasks) {
            var subtask = parent.Subtasks.FirstOrDefault(st => st.Id == taskId);
            if (subtask != null) return subtask;
        }
        return null;
    }
    
    // Task Filtering (from TaskListScreen)
    public static List<SimpleTask> GetFilteredTasks() {
        var filtered = allTasks.Where(t => t.IsParent()).ToList();
        
        switch (currentFilter) {
            case "Today":
                filtered = filtered.Where(t => t.DueDate?.Date == DateTime.Today).ToList();
                break;
            case "High":
                filtered = filtered.Where(t => t.Priority == "High").ToList();
                break;
            case "Medium":
                filtered = filtered.Where(t => t.Priority == "Medium").ToList();
                break;
            case "Low":
                filtered = filtered.Where(t => t.Priority == "Low").ToList();
                break;
        }
        
        if (!showCompletedTasks) {
            filtered = filtered.Where(t => !t.Completed).ToList();
        }
        
        if (!string.IsNullOrEmpty(searchTerm)) {
            filtered = filtered.Where(t => t.Title.Contains(searchTerm, StringComparison.OrdinalIgnoreCase) ||
                                         t.Tags.Any(tag => tag.Contains(searchTerm, StringComparison.OrdinalIgnoreCase)))
                             .ToList();
        }
        
        return filtered.OrderBy(t => t.SortOrder).ThenBy(t => t.CreatedDate).ToList();
    }
    
    public static void ToggleFilter() {
        currentFilter = currentFilter switch {
            "All" => "Today",
            "Today" => "High",
            "High" => "Medium",
            "Medium" => "Low",
            "Low" => "All",
            _ => "All"
        };
    }
    
    public static void ToggleShowCompleted() {
        showCompletedTasks = !showCompletedTasks;
    }
    
    public static void SetSearchTerm(string term) {
        searchTerm = term ?? "";
    }
    
    // ==================== TIME TRACKING BUSINESS LOGIC ====================
    
    private static void LoadTimeEntries() {
        try {
            if (File.Exists(timePath)) {
                var json = File.ReadAllText(timePath);
                timeEntries = JsonSerializer.Deserialize<List<TimeEntry>>(json) ?? new List<TimeEntry>();
            }
        } catch (Exception ex) {
            Console.WriteLine($"Error loading time entries: {ex.Message}");
            timeEntries = new List<TimeEntry>();
        }
    }
    
    // Time Entry CRUD Operations (from TimeEntryScreen)
    public static void CreateNewTimeEntry(string description, string id1Display, string weekEnding) {
        var entry = new TimeEntry {
            Description = description,
            ID1Display = id1Display,
            WeekEndingFriday = weekEnding,
            Created = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
        };
        timeEntries.Add(entry);
        SaveTimeEntries();
    }
    
    public static void CreateProjectTimeEntry(string projectCode, string description) {
        var weekEnding = GetCurrentWeekEndingFriday();
        var entry = new TimeEntry {
            Description = description,
            ID1Display = projectCode,
            WeekEndingFriday = weekEnding,
            IsProjectEntry = true,
            ProjectCode = projectCode,
            Created = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
        };
        timeEntries.Add(entry);
        SaveTimeEntries();
    }
    
    public static void SetTimeEntryValue(string entryId, string day, double hours) {
        var entry = timeEntries.FirstOrDefault(te => te.Id == entryId);
        if (entry != null) {
            entry.SetTimeForDay(day, hours);
            SaveTimeEntries();
        }
    }
    
    public static void UpdateTimeEntryField(string entryId, string field, string value) {
        var entry = timeEntries.FirstOrDefault(te => te.Id == entryId);
        if (entry == null) return;
        
        switch (field.ToLower()) {
            case "description": entry.Description = value; break;
            case "id1display": entry.ID1Display = value; break;
            case "weekendingfriday": entry.WeekEndingFriday = value; break;
            case "projectcode": entry.ProjectCode = value; break;
        }
        entry.Modified = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        SaveTimeEntries();
    }
    
    public static void DeleteTimeEntry(string entryId) {
        timeEntries.RemoveAll(te => te.Id == entryId);
        SaveTimeEntries();
    }
    
    // Time Entry Filtering and Lookup
    public static List<TimeEntry> GetTimeEntriesForWeek(string weekEnding) {
        return timeEntries.Where(te => te.WeekEndingFriday == weekEnding)
                         .OrderBy(te => te.Description)
                         .ToList();
    }
    
    public static List<TimeEntry> GetProjectTimeEntries() {
        return timeEntries.Where(te => te.IsProjectEntry)
                         .OrderByDescending(te => te.WeekEndingFriday)
                         .ThenBy(te => te.Description)
                         .ToList();
    }
    
    private static string GetCurrentWeekEndingFriday() {
        var today = DateTime.Today;
        var friday = today.AddDays(5 - (int)today.DayOfWeek);
        return friday.ToString("yyyyMMdd");
    }
    
    // ==================== COMMAND LIBRARY BUSINESS LOGIC ====================
    
    private static void LoadCommands() {
        try {
            if (File.Exists(commandsPath)) {
                var json = File.ReadAllText(commandsPath);
                commands = JsonSerializer.Deserialize<List<Command>>(json) ?? new List<Command>();
            }
        } catch (Exception ex) {
            Console.WriteLine($"Error loading commands: {ex.Message}");
            commands = new List<Command>();
        }
    }
    
    // Command CRUD Operations (from CommandLibraryScreen)
    public static void CreateNewCommand(string title, string commandText, string description = "", string groupId = "") {
        var command = new Command {
            Title = title,
            CommandText = commandText,
            Description = description,
            GroupId = groupId,
            CreatedDate = DateTime.Now
        };
        
        if (!string.IsNullOrEmpty(groupId)) {
            var group = commands.FirstOrDefault(c => c.Id == groupId);
            group?.Commands.Add(command);
        } else {
            commands.Add(command);
        }
        SaveCommands();
    }
    
    public static void CreateNewCommandGroup(string title, string description = "") {
        var group = new Command {
            Title = title,
            Description = description,
            CreatedDate = DateTime.Now
        };
        commands.Add(group);
        SaveCommands();
    }
    
    public static void UpdateCommandField(string commandId, string field, string value) {
        var command = FindCommandById(commandId);
        if (command == null) return;
        
        switch (field.ToLower()) {
            case "title": command.Title = value; break;
            case "commandtext": command.CommandText = value; break;
            case "description": command.Description = value; break;
            case "tags":
                command.Tags = value.Split(',', StringSplitOptions.RemoveEmptyEntries)
                                   .Select(t => t.Trim()).ToList();
                break;
        }
        command.ModifiedDate = DateTime.Now;
        SaveCommands();
    }
    
    public static void DeleteCommand(string commandId) {
        var command = FindCommandById(commandId);
        if (command == null) return;
        
        if (command.IsGroup() && command.Commands.Any()) {
            throw new InvalidOperationException("Cannot delete non-empty command group");
        }
        
        commands.RemoveAll(c => c.Id == commandId);
        
        // Remove from parent groups
        foreach (var group in commands.Where(c => c.IsGroup())) {
            group.Commands.RemoveAll(c => c.Id == commandId);
        }
        SaveCommands();
    }
    
    public static string ExecuteCommand(string commandId) {
        var command = FindCommandById(commandId);
        if (command == null || string.IsNullOrWhiteSpace(command.CommandText)) {
            return "Command not found or has no executable text";
        }
        
        try {
            var processInfo = new ProcessStartInfo {
                FileName = "pwsh",
                Arguments = $"-Command \"{command.CommandText}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };
            
            using (var process = Process.Start(processInfo)) {
                var output = process.StandardOutput.ReadToEnd();
                var error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                
                var result = output;
                if (!string.IsNullOrEmpty(error)) {
                    result += "\nErrors:\n" + error;
                }
                return result;
            }
        } catch (Exception ex) {
            return $"Command execution failed: {ex.Message}";
        }
    }
    
    private static Command FindCommandById(string commandId) {
        var command = commands.FirstOrDefault(c => c.Id == commandId);
        if (command != null) return command;
        
        // Search in group commands
        foreach (var group in commands.Where(c => c.IsGroup())) {
            var groupCommand = group.Commands.FirstOrDefault(gc => gc.Id == commandId);
            if (groupCommand != null) return groupCommand;
        }
        return null;
    }
    
    public static List<Command> GetFilteredCommands(string tagFilter = "") {
        var filtered = commands.ToList();
        
        if (!string.IsNullOrEmpty(tagFilter)) {
            filtered = filtered.Where(c => c.Tags.Any(tag => tag.Contains(tagFilter, StringComparison.OrdinalIgnoreCase)))
                              .ToList();
        }
        
        return filtered.OrderBy(c => c.SortOrder).ThenBy(c => c.Title).ToList();
    }
    
    // ==================== EXCEL MAPPING BUSINESS LOGIC ====================
    
    private static void LoadExcelMappings() {
        try {
            if (File.Exists(excelMappingsPath)) {
                var json = File.ReadAllText(excelMappingsPath);
                excelMappings = JsonSerializer.Deserialize<List<ExcelMapping>>(json) ?? new List<ExcelMapping>();
            }
        } catch (Exception ex) {
            Console.WriteLine($"Error loading Excel mappings: {ex.Message}");
            excelMappings = new List<ExcelMapping>();
        }
    }
    
    // Excel Mapping CRUD Operations (from ExcelMappingScreen)
    public static void CreateNewExcelMapping(string displayName, string sourceCell, string destinationCell, string category = "") {
        var mapping = new ExcelMapping {
            DisplayName = displayName,
            SourceCell = sourceCell,
            DestinationCell = destinationCell,
            Category = category
        };
        excelMappings.Add(mapping);
        SaveExcelMappings();
    }
    
    public static void UpdateExcelMappingField(string mappingId, string field, string value) {
        var mapping = excelMappings.FirstOrDefault(em => em.Id == mappingId);
        if (mapping == null) return;
        
        switch (field.ToLower()) {
            case "displayname": mapping.DisplayName = value; break;
            case "sourcecell": mapping.SourceCell = value; break;
            case "destinationcell": mapping.DestinationCell = value; break;
            case "t2020name": mapping.T2020Name = value; break;
            case "category": mapping.Category = value; break;
        }
        SaveExcelMappings();
    }
    
    public static void ToggleMappingT2020Include(string mappingId) {
        var mapping = excelMappings.FirstOrDefault(em => em.Id == mappingId);
        if (mapping != null) {
            mapping.IncludeInT2020 = !mapping.IncludeInT2020;
            SaveExcelMappings();
        }
    }
    
    public static void MoveMappingUp(string mappingId) {
        var mapping = excelMappings.FirstOrDefault(em => em.Id == mappingId);
        if (mapping != null && mapping.SortOrder > 0) {
            mapping.SortOrder--;
            SaveExcelMappings();
        }
    }
    
    public static void MoveMappingDown(string mappingId) {
        var mapping = excelMappings.FirstOrDefault(em => em.Id == mappingId);
        if (mapping != null) {
            mapping.SortOrder++;
            SaveExcelMappings();
        }
    }
    
    public static List<ExcelMapping> GetMappingsByCategory(string category) {
        return excelMappings.Where(em => em.Category == category)
                           .OrderBy(em => em.SortOrder)
                           .ToList();
    }
    
    public static List<string> GetMappingCategories() {
        return excelMappings.Select(em => em.Category)
                           .Where(c => !string.IsNullOrEmpty(c))
                           .Distinct()
                           .OrderBy(c => c)
                           .ToList();
    }
    
    // ==================== EXPORT AND INTEGRATION ====================
    
    // Multi-format Export (from ExcelDataScreen)
    public static void ExportTasksToCSV(string filePath = null) {
        filePath ??= $"tasks_export_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
        var lines = new List<string> { "Title,Status,Priority,Created,Due,Tags,Notes,ID1,ID2" };
        
        foreach (var task in allTasks) {
            var tags = task.Tags ?? new List<string>();
            var line = $"\"{task.Title}\",{(task.Completed ? "Completed" : "Pending")},{task.Priority}," +
                      $"{task.CreatedDate:yyyy-MM-dd},{task.DueDate?.ToString("yyyy-MM-dd") ?? ""}," +
                      $"\"{string.Join(";", tags)}\",\"{task.Notes ?? ""}\",{task.ID1 ?? ""},{task.ID2 ?? ""}";
            lines.Add(line);
        }
        
        File.WriteAllLines(filePath, lines);
    }
    
    public static void ExportTimeToCSV(string filePath = null) {
        filePath ??= $"time_export_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
        var lines = new List<string> { "Description,Code,WeekEnding,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday,Total" };
        
        foreach (var entry in timeEntries) {
            var line = $"\"{entry.Description}\",{entry.ID1Display},{entry.WeekEndingFriday}," +
                      $"{entry.Monday},{entry.Tuesday},{entry.Wednesday},{entry.Thursday}," +
                      $"{entry.Friday},{entry.Saturday},{entry.Sunday},{entry.TotalHours}";
            lines.Add(line);
        }
        
        File.WriteAllLines(filePath, lines);
    }
    
    public static void ExportCommandsToCSV(string filePath = null) {
        filePath ??= $"commands_export_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
        var lines = new List<string> { "Title,CommandText,Description,Tags,IsGroup" };
        
        foreach (var cmd in commands) {
            var tags = cmd.Tags ?? new List<string>();
            var line = $"\"{cmd.Title}\",\"{cmd.CommandText ?? ""}\",\"{cmd.Description ?? ""}\"," +
                      $"\"{string.Join(";", tags)}\",{cmd.IsGroup()}";
            lines.Add(line);
        }
        
        File.WriteAllLines(filePath, lines);
    }
    
    // ==================== SAVE OPERATIONS ====================
    
    private static void SaveTasks() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(allTasks, options);
            Directory.CreateDirectory(Path.GetDirectoryName(tasksPath) ?? ".");
            File.WriteAllText(tasksPath, json);
        } catch (Exception ex) {
            Console.WriteLine($"Error saving tasks: {ex.Message}");
        }
    }
    
    private static void SaveTimeEntries() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(timeEntries, options);
            Directory.CreateDirectory(Path.GetDirectoryName(timePath) ?? ".");
            File.WriteAllText(timePath, json);
        } catch (Exception ex) {
            Console.WriteLine($"Error saving time entries: {ex.Message}");
        }
    }
    
    private static void SaveCommands() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(commands, options);
            Directory.CreateDirectory(Path.GetDirectoryName(commandsPath) ?? ".");
            File.WriteAllText(commandsPath, json);
        } catch (Exception ex) {
            Console.WriteLine($"Error saving commands: {ex.Message}");
        }
    }
    
    private static void SaveExcelMappings() {
        try {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(excelMappings, options);
            Directory.CreateDirectory(Path.GetDirectoryName(excelMappingsPath) ?? ".");
            File.WriteAllText(excelMappingsPath, json);
        } catch (Exception ex) {
            Console.WriteLine($"Error saving Excel mappings: {ex.Message}");
        }
    }
    
    // ==================== MAIN API ====================
    
    public static void Main(string mode = "tasks", string command = "", bool interactive = false) {
        Initialize();
        
        if (!string.IsNullOrEmpty(command)) {
            HandleCommand(command);
            return;
        }
        
        if (interactive) {
            RunInteractiveMode();
        } else {
            ShowStatus();
        }
    }
    
    private static void HandleCommand(string command) {
        var parts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var action = parts[0].ToLower();
        
        switch (action) {
            case "export-all":
                ExportTasksToCSV();
                ExportTimeToCSV();
                ExportCommandsToCSV();
                Console.WriteLine("All data exported to CSV files");
                break;
            case "export-tasks":
                ExportTasksToCSV();
                Console.WriteLine("Tasks exported to CSV");
                break;
            case "export-time":
                ExportTimeToCSV();
                Console.WriteLine("Time entries exported to CSV");
                break;
            case "export-commands":
                ExportCommandsToCSV();
                Console.WriteLine("Commands exported to CSV");
                break;
            case "list-tasks":
                foreach (var task in GetFilteredTasks()) {
                    Console.WriteLine($"{task.StatusIcon} {task.Title} [{task.Priority}]");
                }
                break;
            case "execute-command":
                if (parts.Length > 1) {
                    var result = ExecuteCommand(parts[1]);
                    Console.WriteLine(result);
                }
                break;
            default:
                Console.WriteLine($"Unknown command: {action}");
                break;
        }
    }
    
    private static void ShowStatus() {
        Console.WriteLine("=== Unified Task Manager Status ===");
        Console.WriteLine($"Current Mode: {currentMode}");
        Console.WriteLine($"Selected Index: {selectedIndex}");
        Console.WriteLine($"Tasks: {allTasks.Count} total");
        Console.WriteLine($"Time Entries: {timeEntries.Count} total");
        Console.WriteLine($"Commands: {commands.Count} total");
        Console.WriteLine($"Excel Mappings: {excelMappings.Count} total");
        Console.WriteLine();
        Console.WriteLine("Available commands:");
        Console.WriteLine("  export-all, export-tasks, export-time, export-commands");
        Console.WriteLine("  list-tasks, execute-command <id>");
    }
    
    private static void RunInteractiveMode() {
        Console.WriteLine("Interactive mode not yet implemented - use command mode");
    }
}
'@

Write-Host "Compiling Unified Task Manager with complete business logic..." -ForegroundColor Yellow

try {
    Add-Type -TypeDefinition $UnifiedManagerSource -Language CSharp
    
    Write-Host "✓ Compilation successful!" -ForegroundColor Green
    Write-Host "Starting Unified Task Manager..." -ForegroundColor Cyan
    Write-Host ""
    
    [TaskManager]::Main($Mode, $Command, $Interactive)
    
} catch {
    Write-Host "✗ Compilation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}