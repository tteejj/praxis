using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace TaskPro.Data {
    public class TaskPersistence {
        private string filePath;
        private string backupDirectory;
        
        public TaskPersistence(string dataFilePath) {
            filePath = dataFilePath;
            backupDirectory = Path.Combine(Path.GetDirectoryName(filePath), "backups");
            Directory.CreateDirectory(backupDirectory);
        }
        
        public List<SimpleTask> LoadTasks() {
            try {
                if (!File.Exists(filePath)) {
                    return new List<SimpleTask>();
                }
                
                var json = File.ReadAllText(filePath);
                var tasks = JsonSerializer.Deserialize<List<SimpleTask>>(json, GetJsonOptions());
                return tasks ?? new List<SimpleTask>();
            }
            catch (Exception ex) {
                // Try to load from most recent backup
                var backups = GetBackupFiles().OrderByDescending(f => f.CreationTime).ToList();
                foreach (var backup in backups.Take(3)) {
                    try {
                        var json = File.ReadAllText(backup.FullName);
                        var tasks = JsonSerializer.Deserialize<List<SimpleTask>>(json, GetJsonOptions());
                        return tasks ?? new List<SimpleTask>();
                    }
                    catch {
                        continue; // Try next backup
                    }
                }
                
                throw new InvalidOperationException($"Could not load tasks from {filePath} or any backup: {ex.Message}");
            }
        }
        
        public void SaveTasks(List<SimpleTask> tasks) {
            try {
                // Create backup before saving
                CreateBackup();
                
                var json = JsonSerializer.Serialize(tasks, GetJsonOptions());
                
                // Atomic save using temp file
                var tempFile = filePath + ".tmp";
                File.WriteAllText(tempFile, json);
                File.Move(tempFile, filePath, true);
                
                // Clean old backups (keep last 10)
                CleanOldBackups();
            }
            catch (Exception ex) {
                throw new InvalidOperationException($"Failed to save tasks to {filePath}: {ex.Message}");
            }
        }
        
        private void CreateBackup() {
            if (File.Exists(filePath)) {
                var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                var backupFile = Path.Combine(backupDirectory, $"tasks_backup_{timestamp}.json");
                File.Copy(filePath, backupFile);
            }
        }
        
        private void CleanOldBackups() {
            var backups = GetBackupFiles().OrderByDescending(f => f.CreationTime).ToList();
            foreach (var backup in backups.Skip(10)) {
                try {
                    backup.Delete();
                }
                catch {
                    // Ignore cleanup errors
                }
            }
        }
        
        private FileInfo[] GetBackupFiles() {
            var backupDir = new DirectoryInfo(backupDirectory);
            return backupDir.Exists ? backupDir.GetFiles("tasks_backup_*.json") : new FileInfo[0];
        }
        
        private JsonSerializerOptions GetJsonOptions() {
            return new JsonSerializerOptions {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
        }
    }
}