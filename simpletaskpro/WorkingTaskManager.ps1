#!/usr/bin/env pwsh
# WorkingTaskManager.ps1 - Actually functional task manager
# Uses PowerShell Add-Type for reliable C# execution without compilation

param([string]$Command = "")

# Embedded C# source - compiled in memory, no files created
$TaskManagerSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Linq;

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
    
    // Display properties
    public string DisplayTitle => string.IsNullOrEmpty(Title) ? "[No Title]" : Title;
    public string StatusIcon => Completed ? "■" : "☐";
    public string PriorityIcon => Priority switch {
        "High" => "H",
        "Medium" => "M", 
        "Low" => "L",
        _ => " "
    };
}

public static class TaskManager {
    private static List<SimpleTask> allTasks = new List<SimpleTask>();
    private static List<SimpleTask> flatList = new List<SimpleTask>();
    private static int selectedIndex = 0;
    private static string dataPath = "Data/tasks.json";
    
    public static void Main(string command = "") {
        Console.Clear();
        LoadTasks();
        
        if (!string.IsNullOrEmpty(command)) {
            HandleCommand(command);
            return;
        }
        
        RunInteractiveMode();
    }
    
    private static void LoadTasks() {
        try {
            if (!File.Exists(dataPath)) {
                Console.WriteLine($"Task file not found: {dataPath}");
                Console.WriteLine("Creating sample tasks...");
                CreateSampleTasks();
                return;
            }
            
            var json = File.ReadAllText(dataPath);
            allTasks = JsonSerializer.Deserialize<List<SimpleTask>>(json) ?? new List<SimpleTask>();
            BuildFlatList();
            
            Console.WriteLine($"Loaded {allTasks.Count} tasks from {dataPath}");
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
            },
            new SimpleTask { 
                Title = "Test new features", 
                Priority = "Low",
                CreatedDate = DateTime.Now,
                Completed = true
            }
        };
        BuildFlatList();
    }
    
    private static void BuildFlatList() {
        flatList.Clear();
        foreach (var task in allTasks.Where(t => string.IsNullOrEmpty(t.ParentId))) {
            flatList.Add(task);
            if (!task.SubtasksCollapsed) {
                flatList.AddRange(task.Subtasks);
            }
        }
        
        // Keep selection in bounds
        if (selectedIndex >= flatList.Count) {
            selectedIndex = Math.Max(0, flatList.Count - 1);
        }
    }
    
    private static void RunInteractiveMode() {
        bool running = true;
        
        while (running) {
            DisplayTasks();
            DisplayHelp();
            
            Console.Write("\nCommand (or key): ");
            var key = Console.ReadKey(true);
            
            switch (key.Key) {
                case ConsoleKey.Q:
                case ConsoleKey.Escape:
                    running = false;
                    break;
                    
                case ConsoleKey.UpArrow:
                    if (selectedIndex > 0) selectedIndex--;
                    break;
                    
                case ConsoleKey.DownArrow:
                    if (selectedIndex < flatList.Count - 1) selectedIndex++;
                    break;
                    
                case ConsoleKey.N:
                    CreateNewTask();
                    break;
                    
                case ConsoleKey.D:
                case ConsoleKey.Delete:
                    DeleteCurrentTask();
                    break;
                    
                case ConsoleKey.X:
                case ConsoleKey.Spacebar:
                    ToggleCurrentTask();
                    break;
                    
                case ConsoleKey.Enter:
                    EditCurrentTask();
                    break;
                    
                case ConsoleKey.S:
                    SaveTasks();
                    break;
                    
                case ConsoleKey.R:
                    LoadTasks();
                    break;
                    
                default:
                    Console.WriteLine($"\nUnknown key: {key.Key}");
                    Console.WriteLine("Press any key to continue...");
                    Console.ReadKey(true);
                    break;
            }
            
            Console.Clear();
        }
        
        Console.WriteLine("Task Manager exited. Have a great day!");
    }
    
    private static void DisplayTasks() {
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("═══════════════════════════════════════════════════════════════════");
        Console.WriteLine("                          TASK MANAGER                            ");  
        Console.WriteLine("═══════════════════════════════════════════════════════════════════");
        Console.ResetColor();
        
        if (flatList.Count == 0) {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n  No tasks found. Press 'N' to create a new task.");
            Console.ResetColor();
            return;
        }
        
        Console.WriteLine("\n St Pri  Created      Due          Title");
        Console.WriteLine(" ──────────────────────────────────────────────────────────────────");
        
        for (int i = 0; i < flatList.Count; i++) {
            var task = flatList[i];
            bool isSelected = (i == selectedIndex);
            
            // Highlight selected task
            if (isSelected) {
                Console.BackgroundColor = ConsoleColor.Blue;
                Console.ForegroundColor = ConsoleColor.White;
                Console.Write(">");
            } else {
                Console.Write(" ");
            }
            
            // Status
            if (task.Completed) {
                Console.ForegroundColor = ConsoleColor.Green;
            } else {
                Console.ForegroundColor = ConsoleColor.White;
            }
            Console.Write($" {task.StatusIcon}  ");
            
            // Priority
            Console.ForegroundColor = task.Priority switch {
                "High" => ConsoleColor.Red,
                "Medium" => ConsoleColor.Yellow,
                "Low" => ConsoleColor.Green,
                _ => ConsoleColor.Gray
            };
            Console.Write($" {task.PriorityIcon}  ");
            
            // Dates
            Console.ForegroundColor = ConsoleColor.Gray;
            var created = task.CreatedDate.ToString("MM-dd");
            var due = task.DueDate?.ToString("MM-dd") ?? "     ";
            Console.Write($" {created}       {due}        ");
            
            // Title
            Console.ForegroundColor = task.Completed ? ConsoleColor.DarkGreen : ConsoleColor.White;
            var title = task.DisplayTitle;
            if (title.Length > 40) title = title.Substring(0, 37) + "...";
            Console.Write(title);
            
            // Tags
            if (task.Tags.Any()) {
                Console.ForegroundColor = ConsoleColor.DarkGray;
                Console.Write($" [{string.Join(", ", task.Tags)}]");
            }
            
            Console.ResetColor();
            Console.WriteLine();
        }
        
        Console.WriteLine($"\nShowing {flatList.Count} tasks | Selected: {selectedIndex + 1}");
    }
    
    private static void DisplayHelp() {
        Console.ForegroundColor = ConsoleColor.DarkCyan;
        Console.WriteLine("\n↑↓: Navigate | N: New | D: Delete | X: Toggle | Enter: Edit | S: Save | R: Reload | Q: Quit");
        Console.ResetColor();
    }
    
    private static void CreateNewTask() {
        Console.Clear();
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("═══ CREATE NEW TASK ═══");
        Console.ResetColor();
        
        Console.Write("Title: ");
        var title = Console.ReadLine() ?? "";
        
        if (string.IsNullOrWhiteSpace(title)) {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("Task title cannot be empty!");
            Console.ResetColor();
            Console.WriteLine("Press any key to continue...");
            Console.ReadKey(true);
            return;
        }
        
        Console.Write("Priority (H/M/L) [M]: ");
        var priority = Console.ReadLine()?.ToUpper();
        priority = priority switch {
            "H" => "High",
            "L" => "Low", 
            _ => "Medium"
        };
        
        Console.Write("Tags (comma-separated): ");
        var tagInput = Console.ReadLine() ?? "";
        var tags = tagInput.Split(',', StringSplitOptions.RemoveEmptyEntries)
                          .Select(t => t.Trim())
                          .Where(t => !string.IsNullOrEmpty(t))
                          .ToList();
        
        var newTask = new SimpleTask {
            Title = title,
            Priority = priority,
            Tags = tags,
            CreatedDate = DateTime.Now
        };
        
        allTasks.Add(newTask);
        BuildFlatList();
        
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"\nTask '{title}' created successfully!");
        Console.ResetColor();
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey(true);
    }
    
    private static void DeleteCurrentTask() {
        if (flatList.Count == 0) return;
        
        var task = flatList[selectedIndex];
        
        Console.Clear();
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine($"Delete task: {task.DisplayTitle}");
        Console.WriteLine("Are you sure? (y/N): ");
        Console.ResetColor();
        
        var confirm = Console.ReadKey(true);
        if (confirm.Key == ConsoleKey.Y) {
            allTasks.Remove(task);
            BuildFlatList();
            
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Task deleted!");
            Console.ResetColor();
        } else {
            Console.WriteLine("Cancelled.");
        }
        
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey(true);
    }
    
    private static void ToggleCurrentTask() {
        if (flatList.Count == 0) return;
        
        var task = flatList[selectedIndex];
        task.Completed = !task.Completed;
        
        Console.Clear();
        Console.ForegroundColor = task.Completed ? ConsoleColor.Green : ConsoleColor.Yellow;
        Console.WriteLine($"Task '{task.DisplayTitle}' marked as {(task.Completed ? "COMPLETED" : "INCOMPLETE")}");
        Console.ResetColor();
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey(true);
    }
    
    private static void EditCurrentTask() {
        if (flatList.Count == 0) return;
        
        var task = flatList[selectedIndex];
        
        Console.Clear();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"═══ EDIT TASK ═══");
        Console.WriteLine($"Current: {task.DisplayTitle}");
        Console.ResetColor();
        
        Console.Write($"Title [{task.Title}]: ");
        var newTitle = Console.ReadLine();
        if (!string.IsNullOrWhiteSpace(newTitle)) {
            task.Title = newTitle;
        }
        
        Console.Write($"Priority [{task.Priority}] (H/M/L): ");
        var priorityInput = Console.ReadLine()?.ToUpper();
        if (!string.IsNullOrWhiteSpace(priorityInput)) {
            task.Priority = priorityInput switch {
                "H" => "High",
                "L" => "Low",
                _ => "Medium"
            };
        }
        
        Console.Write($"Notes [{task.Notes}]: ");
        var newNotes = Console.ReadLine();
        if (newNotes != null) {
            task.Notes = newNotes;
        }
        
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Task updated!");
        Console.ResetColor();
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey(true);
    }
    
    private static void SaveTasks() {
        try {
            var options = new JsonSerializerOptions {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            
            var json = JsonSerializer.Serialize(allTasks, options);
            Directory.CreateDirectory(Path.GetDirectoryName(dataPath) ?? ".");
            File.WriteAllText(dataPath, json);
            
            Console.Clear();
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"Tasks saved to {dataPath}");
            Console.ResetColor();
            Console.WriteLine("Press any key to continue...");
            Console.ReadKey(true);
        } catch (Exception ex) {
            Console.Clear();
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"Error saving tasks: {ex.Message}");
            Console.ResetColor();
            Console.WriteLine("Press any key to continue...");
            Console.ReadKey(true);
        }
    }
    
    private static void HandleCommand(string command) {
        switch (command.ToLower()) {
            case "list":
            case "show":
                DisplayTasks();
                break;
            case "new":
            case "create":
                CreateNewTask();
                break;
            case "save":
                SaveTasks();
                break;
            case "help":
                DisplayHelp();
                break;
            default:
                Console.WriteLine($"Unknown command: {command}");
                Console.WriteLine("Available: list, new, save, help");
                break;
        }
    }
}
'@

Write-Host "Compiling Task Manager..." -ForegroundColor Yellow

try {
    # Compile the C# code in memory - no files created
    Add-Type -TypeDefinition $TaskManagerSource -Language CSharp
    
    Write-Host "✓ Compilation successful!" -ForegroundColor Green
    Write-Host "Starting Task Manager..." -ForegroundColor Cyan
    Write-Host ""
    
    # Run the task manager
    [TaskManager]::Main($Command)
    
} catch {
    Write-Host "✗ Compilation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "This usually means:"
    Write-Host "1. .NET runtime not available"
    Write-Host "2. PowerShell version too old" 
    Write-Host "3. Execution policy restrictions"
    Write-Host ""
    Write-Host "Try running: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass"
}