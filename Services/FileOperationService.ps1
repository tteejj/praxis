# FileOperationService.ps1 - Handles file copy/cut/paste/rename/delete operations

class FileOperationService {
    [ServiceContainer]$ServiceContainer
    
    # Clipboard for file operations
    [System.Collections.ArrayList]$YankBuffer
    [bool]$IsCutOperation = $false
    
    # Operation history for undo (future feature)
    [System.Collections.ArrayList]$OperationHistory
    
    FileOperationService() {
        $this.YankBuffer = [System.Collections.ArrayList]::new()
        $this.OperationHistory = [System.Collections.ArrayList]::new()
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.ServiceContainer = $container
    }
    
    # Copy files/directories to yank buffer
    [void] YankItems([string[]]$paths, [bool]$cut = $false) {
        $this.YankBuffer.Clear()
        $this.IsCutOperation = $cut
        
        foreach ($path in $paths) {
            if (Test-Path $path) {
                $this.YankBuffer.Add($path) | Out-Null
            }
        }
        
        $operation = if ($cut) { "Cut" } else { "Copied" }
        $count = $this.YankBuffer.Count
        $itemText = if ($count -eq 1) { "item" } else { "items" }
        
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $eventBus.Publish('FileOperation', @{
                Operation = $operation
                Message = "$operation $count $itemText"
                Items = $this.YankBuffer
            })
        }
    }
    
    # Paste yanked items to destination
    [hashtable] PasteItems([string]$destinationPath) {
        $result = @{
            Success = $true
            Message = ""
            ProcessedCount = 0
            Errors = @()
        }
        
        if ($this.YankBuffer.Count -eq 0) {
            $result.Success = $false
            $result.Message = "Nothing to paste"
            return $result
        }
        
        if (-not (Test-Path $destinationPath -PathType Container)) {
            $result.Success = $false
            $result.Message = "Destination must be a directory"
            return $result
        }
        
        $operation = if ($this.IsCutOperation) { "Moving" } else { "Copying" }
        $processed = 0
        
        foreach ($sourcePath in $this.YankBuffer) {
            try {
                $item = Get-Item $sourcePath -ErrorAction Stop
                $destPath = Join-Path $destinationPath $item.Name
                
                # Check if destination exists
                if (Test-Path $destPath) {
                    $destPath = $this.GetUniqueDestinationPath($destPath)
                }
                
                if ($this.IsCutOperation) {
                    Move-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
                } else {
                    if ($item.PSIsContainer) {
                        Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force -ErrorAction Stop
                    } else {
                        Copy-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
                    }
                }
                
                $processed++
                
                # Record operation for history
                $this.OperationHistory.Add(@{
                    Type = if ($this.IsCutOperation) { 'Move' } else { 'Copy' }
                    Source = $sourcePath
                    Destination = $destPath
                    Timestamp = Get-Date
                }) | Out-Null
                
            } catch {
                $result.Errors += "Failed to process ${sourcePath}: $_"
            }
        }
        
        $result.ProcessedCount = $processed
        
        if ($processed -gt 0) {
            if ($this.IsCutOperation) {
                $this.YankBuffer.Clear()
                $this.IsCutOperation = $false
            }
            
            $itemText = if ($processed -eq 1) { "item" } else { "items" }
            $result.Message = "$operation complete: $processed $itemText"
        } else {
            $result.Success = $false
            $result.Message = "No items were processed"
        }
        
        # Publish event
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $eventBus.Publish('FileOperation', @{
                Operation = 'Paste'
                Result = $result
            })
        }
        
        return $result
    }
    
    # Rename a file or directory
    [hashtable] RenameItem([string]$path, [string]$newName) {
        $result = @{
            Success = $true
            Message = ""
            NewPath = ""
        }
        
        if (-not (Test-Path $path)) {
            $result.Success = $false
            $result.Message = "Item not found: $path"
            return $result
        }
        
        try {
            $item = Get-Item $path -ErrorAction Stop
            $directory = Split-Path $path -Parent
            $newPath = Join-Path $directory $newName
            
            # Check if new name already exists
            if (Test-Path $newPath) {
                $result.Success = $false
                $result.Message = "An item with that name already exists"
                return $result
            }
            
            # Rename the item
            Rename-Item -Path $path -NewName $newName -Force -ErrorAction Stop
            
            $result.NewPath = $newPath
            $result.Message = "Renamed to: $newName"
            
            # Record operation
            $this.OperationHistory.Add(@{
                Type = 'Rename'
                Source = $path
                Destination = $newPath
                Timestamp = Get-Date
            }) | Out-Null
            
        } catch {
            $result.Success = $false
            $result.Message = "Rename failed: $_"
        }
        
        # Publish event
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $eventBus.Publish('FileOperation', @{
                Operation = 'Rename'
                Result = $result
            })
        }
        
        return $result
    }
    
    # Delete files/directories with confirmation
    [hashtable] DeleteItems([string[]]$paths, [bool]$skipConfirmation = $false) {
        $result = @{
            Success = $true
            Message = ""
            DeletedCount = 0
            Errors = @()
        }
        
        if ($paths.Count -eq 0) {
            $result.Success = $false
            $result.Message = "No items to delete"
            return $result
        }
        
        $deleted = 0
        
        foreach ($path in $paths) {
            try {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                    $deleted++
                    
                    # Record operation
                    $this.OperationHistory.Add(@{
                        Type = 'Delete'
                        Source = $path
                        Timestamp = Get-Date
                    }) | Out-Null
                }
            } catch {
                $result.Errors += "Failed to delete ${path}: $_"
            }
        }
        
        $result.DeletedCount = $deleted
        
        if ($deleted -gt 0) {
            $itemText = if ($deleted -eq 1) { "item" } else { "items" }
            $result.Message = "Deleted $deleted $itemText"
        } else {
            $result.Success = $false
            $result.Message = "No items were deleted"
        }
        
        # Publish event
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $eventBus.Publish('FileOperation', @{
                Operation = 'Delete'
                Result = $result
            })
        }
        
        return $result
    }
    
    # Get unique destination path by appending number
    [string] GetUniqueDestinationPath([string]$path) {
        $directory = Split-Path $path -Parent
        $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $extension = [System.IO.Path]::GetExtension($path)
        
        $counter = 1
        $newPath = $path
        
        while (Test-Path $newPath) {
            $newName = "${nameWithoutExt}_${counter}${extension}"
            $newPath = Join-Path $directory $newName
            $counter++
        }
        
        return $newPath
    }
    
    # Clear yank buffer
    [void] ClearYankBuffer() {
        $this.YankBuffer.Clear()
        $this.IsCutOperation = $false
    }
    
    # Get yank buffer info
    [hashtable] GetYankBufferInfo() {
        return @{
            Count = $this.YankBuffer.Count
            IsCut = $this.IsCutOperation
            Items = @($this.YankBuffer)
        }
    }
}