using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class JsonDataService : IDataService
    {
        private readonly string _dataFilePath;
        private readonly JsonSerializerOptions _jsonOptions;

        public JsonDataService(string dataFilePath = "data.json")
        {
            _dataFilePath = dataFilePath;
            _jsonOptions = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                Converters = { new JsonStringEnumConverter() }
            };

            Logger.Debug("JsonDataService", $"Initialized with file: {_dataFilePath}");
        }

        public ObservableCollection<TaskItem> LoadItems()
        {
            try
            {
                if (!File.Exists(_dataFilePath))
                {
                    Logger.Info("JsonDataService", $"Data file not found, creating new: {_dataFilePath}");
                    return new ObservableCollection<TaskItem>();
                }

                var jsonString = File.ReadAllText(_dataFilePath);

                // Handle empty or invalid JSON gracefully
                if (string.IsNullOrWhiteSpace(jsonString) || jsonString.Trim() == "[]")
                {
                    return new ObservableCollection<TaskItem>();
                }

                var taskItems = JsonSerializer.Deserialize<TaskItem[]>(jsonString, _jsonOptions);
                var result = new ObservableCollection<TaskItem>();
                
                if (taskItems != null)
                {
                    foreach (var item in taskItems)
                    {
                        FixChildrenHierarchy(item);
                        result.Add(item);
                    }
                }

                Logger.Info("JsonDataService", $"Loaded {result.Count} tasks from {_dataFilePath}");
                return result;
            }
            catch (JsonException jsonEx)
            {
                ErrorHandlingService.HandleWarning(
                    "JsonDataService", 
                    "The data file appears to be corrupted. Starting with empty task list.",
                    $"File: {_dataFilePath}\nError: {jsonEx.Message}");
                return new ObservableCollection<TaskItem>();
            }
            catch (IOException ioEx)
            {
                ErrorHandlingService.HandleWarning(
                    "JsonDataService", 
                    "Cannot read the data file. Starting with empty task list.",
                    $"File: {_dataFilePath}\nError: {ioEx.Message}");
                return new ObservableCollection<TaskItem>();
            }
            catch (Exception ex)
            {
                ErrorHandlingService.HandleCriticalError(
                    "JsonDataService", 
                    "Unexpected error loading tasks. Starting with empty task list.",
                    ex);
                return new ObservableCollection<TaskItem>();
            }
        }

        private void FixChildrenHierarchy(TaskItem item)
        {
            // Recursively ensure children hierarchy is properly connected
            if (item.Children != null)
            {
                foreach (var child in item.Children)
                {
                    FixChildrenHierarchy(child);
                }
            }
        }

        public void SaveItems(ObservableCollection<TaskItem> items)
        {
            try
            {
                // Create backup before saving
                CreateBackupIfExists();

                // Serialize to JSON first (fail fast if serialization issues)
                var taskItems = items.ToArray();
                var jsonString = JsonSerializer.Serialize(taskItems, _jsonOptions);
                
                // Atomic save: write to temp file first, then replace original
                AtomicSaveToFile(jsonString);
                
                Logger.Info("JsonDataService", $"Saved {items.Count} tasks to {_dataFilePath}");
            }
            catch (JsonException jsonEx)
            {
                ErrorHandlingService.HandleError(
                    "JsonDataService", 
                    "Error converting tasks to file format. Data not saved.",
                    jsonEx);
                throw; // Re-throw to let caller handle
            }
            catch (IOException ioEx)
            {
                ErrorHandlingService.HandleError(
                    "JsonDataService", 
                    "Cannot write to data file. Check permissions and disk space.",
                    ioEx,
                    $"File: {_dataFilePath}");
                throw; // Re-throw to let caller handle
            }
            catch (Exception ex)
            {
                ErrorHandlingService.HandleCriticalError(
                    "JsonDataService", 
                    "Unexpected error saving tasks.",
                    ex);
                throw; // Re-throw to let caller handle
            }
        }

        private void CreateBackupIfExists()
        {
            if (File.Exists(_dataFilePath))
            {
                try
                {
                    var backupPath = $"{_dataFilePath}.backup";
                    File.Copy(_dataFilePath, backupPath, overwrite: true);
                    Logger.Debug("JsonDataService", $"Backup created: {backupPath}");
                }
                catch (Exception ex)
                {
                    Logger.Warning("JsonDataService", "Failed to create backup", ex);
                    // Continue with save - backup failure shouldn't prevent saving
                }
            }
        }

        private void AtomicSaveToFile(string jsonString)
        {
            var tempPath = $"{_dataFilePath}.tmp";
            
            try
            {
                // Write to temporary file first
                File.WriteAllText(tempPath, jsonString);
                
                // Verify the temp file was written correctly
                if (!File.Exists(tempPath))
                {
                    throw new IOException("Temporary file was not created successfully");
                }
                
                // Atomic replace - this is the critical operation
                if (File.Exists(_dataFilePath))
                {
                    File.Replace(tempPath, _dataFilePath, null);
                }
                else
                {
                    File.Move(tempPath, _dataFilePath);
                }
            }
            finally
            {
                // Clean up temp file if it still exists
                if (File.Exists(tempPath))
                {
                    try
                    {
                        File.Delete(tempPath);
                    }
                    catch
                    {
                        // Temp file cleanup failure is not critical
                        Logger.Debug("JsonDataService", $"Could not delete temp file: {tempPath}");
                    }
                }
            }
        }


    }
}