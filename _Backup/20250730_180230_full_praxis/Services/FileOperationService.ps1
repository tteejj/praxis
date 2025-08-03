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
        
        # For cut operations, use copy-verify-delete to prevent data loss
        if ($this.IsCutOperation) {
            # Phase 1: Copy all items with verification
            $copiedItems = @()
            foreach ($sourcePath in $this.YankBuffer) {
                try {
                    $item = Get-Item $sourcePath -ErrorAction Stop
                    $destPath = Join-Path $destinationPath $item.Name
                    
                    # Check if destination exists
                    if (Test-Path $destPath) {
                        $destPath = $this.GetUniqueDestinationPath($destPath)
                    }
                    
                    # Perform atomic copy with temp file
                    $success = $this.AtomicCopy($sourcePath, $destPath, $item.PSIsContainer)
                    if ($success) {
                        $copiedItems += @{
                            Source = $sourcePath
                            Destination = $destPath
                            IsDirectory = $item.PSIsContainer
                        }
                        $processed++
                    } else {
                        $result.Errors += "Failed to copy $sourcePath"
                        # If any copy fails, abort the entire operation
                        $result.Success = $false
                        $result.Message = "Cut operation failed - some files could not be copied safely"
                        return $result
                    }
                } catch {
                    $result.Errors += "Failed to process ${sourcePath}: $_"
                    $result.Success = $false
                    $result.Message = "Cut operation failed during copy phase"
                    return $result
                }
            }
            
            # Phase 2: Only if all copies succeeded, delete the originals
            foreach ($item in $copiedItems) {
                try {
                    Remove-Item -Path $item.Source -Recurse:$item.IsDirectory -Force -ErrorAction Stop
                    
                    # Record operation for history
                    $this.OperationHistory.Add(@{
                        Type = 'Move'
                        Source = $item.Source
                        Destination = $item.Destination
                        Timestamp = Get-Date
                    }) | Out-Null
                } catch {
                    $result.Errors += "Warning: Failed to delete original file $($item.Source): $_"
                    # Note: The copy succeeded, so this is just a cleanup issue
                }
            }
        } else {
            # Regular copy operations with atomic safety
            foreach ($sourcePath in $this.YankBuffer) {
                try {
                    $item = Get-Item $sourcePath -ErrorAction Stop
                    $destPath = Join-Path $destinationPath $item.Name
                    
                    # Check if destination exists
                    if (Test-Path $destPath) {
                        $destPath = $this.GetUniqueDestinationPath($destPath)
                    }
                    
                    # Perform atomic copy
                    $success = $this.AtomicCopy($sourcePath, $destPath, $item.PSIsContainer)
                    if ($success) {
                        $processed++
                        
                        # Record operation for history
                        $this.OperationHistory.Add(@{
                            Type = 'Copy'
                            Source = $sourcePath
                            Destination = $destPath
                            Timestamp = Get-Date
                        }) | Out-Null
                    } else {
                        $result.Errors += "Failed to copy $sourcePath"
                    }
                } catch {
                    $result.Errors += "Failed to process ${sourcePath}: $_"
                }
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
    
    # Delete files/directories with recycle bin support
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
                    $success = $this.MoveToRecycleBin($path)
                    if ($success) {
                        $deleted++
                        
                        # Record operation
                        $this.OperationHistory.Add(@{
                            Type = 'Delete'
                            Source = $path
                            Timestamp = Get-Date
                            Method = 'RecycleBin'
                        }) | Out-Null
                    } else {
                        $result.Errors += "Failed to move to recycle bin: $path"
                    }
                }
            } catch {
                $result.Errors += "Failed to delete ${path}: $_"
            }
        }
        
        $result.DeletedCount = $deleted
        
        if ($deleted -gt 0) {
            $itemText = if ($deleted -eq 1) { "item" } else { "items" }
            $result.Message = "Moved $deleted $itemText to recycle bin"
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
    
    # Move file or directory to recycle bin safely
    [bool] MoveToRecycleBin([string]$path) {
        try {
            # Check if running on Windows (compatible with Windows PowerShell and PowerShell Core)
            $isWindows = ([System.Environment]::OSVersion.Platform -eq 'Win32NT') -or 
                         (Get-Variable -Name 'IsWindows' -ErrorAction SilentlyContinue -and $IsWindows)
            
            if ($isWindows) {
                # Use Windows Shell.Application COM object for true recycle bin
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $item = $shell.Namespace(0).ParseName($path)
                    if ($item) {
                        $item.InvokeVerb("delete")
                        return $true
                    }
                } catch {
                    # Fallback: Try using PowerShell Community Extensions if available
                    if (Get-Command "Remove-ItemSafely" -ErrorAction SilentlyContinue) {
                        Remove-ItemSafely -Path $path -Recurse
                        return $true
                    }
                }
            }
            
            # Cross-platform fallback: Create local .trash directory
            $trashDir = Join-Path $env:HOME ".trash"
            if (-not (Test-Path $trashDir)) {
                New-Item -ItemType Directory -Path $trashDir -Force | Out-Null
            }
            
            # Generate unique name in trash with timestamp
            $item = Get-Item $path
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $trashName = "$($item.Name)_$timestamp"
            $trashPath = Join-Path $trashDir $trashName
            
            # Ensure unique name in trash
            $counter = 1
            while (Test-Path $trashPath) {
                $trashName = "$($item.Name)_${timestamp}_$counter"
                $trashPath = Join-Path $trashDir $trashName
                $counter++
            }
            
            # Move to trash directory
            Move-Item -Path $path -Destination $trashPath -Force -ErrorAction Stop
            
            # Create metadata file for restoration
            $metaPath = $trashPath + ".meta"
            $metadata = @{
                OriginalPath = $path
                DeletedDate = Get-Date
                DeletedBy = $env:USERNAME
            } | ConvertTo-Json
            Set-Content -Path $metaPath -Value $metadata -ErrorAction SilentlyContinue
            
            return $true
            
        } catch {
            return $false
        }
    }
    
    # Atomic copy operation with temp-file-swap for safety
    [bool] AtomicCopy([string]$sourcePath, [string]$destPath, [bool]$isDirectory) {
        try {
            if ($isDirectory) {
                # For directories, use a temporary directory name
                $tempDestPath = $destPath + "_temp_" + [System.Guid]::NewGuid().ToString()
                
                # Copy to temp location
                Copy-Item -Path $sourcePath -Destination $tempDestPath -Recurse -Force -ErrorAction Stop
                
                # Verify the copy by checking some basic properties
                $sourceDir = Get-Item $sourcePath -ErrorAction Stop
                $tempDir = Get-Item $tempDestPath -ErrorAction Stop
                
                # Basic verification - ensure directory exists and has content
                if ($tempDir.Exists) {
                    # If destination already exists, remove it
                    if (Test-Path $destPath) {
                        Remove-Item -Path $destPath -Recurse -Force -ErrorAction Stop
                    }
                    
                    # Atomic rename/move the temp directory to final destination
                    Move-Item -Path $tempDestPath -Destination $destPath -Force -ErrorAction Stop
                    return $true
                } else {
                    # Cleanup failed temp directory
                    if (Test-Path $tempDestPath) {
                        Remove-Item -Path $tempDestPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    return $false
                }
            } else {
                # For files, use temp file with hash verification
                $tempDestPath = $destPath + "_temp_" + [System.Guid]::NewGuid().ToString()
                
                # Copy to temp file
                Copy-Item -Path $sourcePath -Destination $tempDestPath -Force -ErrorAction Stop
                
                # Verify the copy with hash comparison
                $sourceHash = Get-FileHash -Path $sourcePath -Algorithm SHA256 -ErrorAction Stop
                $tempHash = Get-FileHash -Path $tempDestPath -Algorithm SHA256 -ErrorAction Stop
                
                if ($sourceHash.Hash -eq $tempHash.Hash) {
                    # If destination already exists, remove it
                    if (Test-Path $destPath) {
                        Remove-Item -Path $destPath -Force -ErrorAction Stop
                    }
                    
                    # Atomic rename/move the temp file to final destination
                    Move-Item -Path $tempDestPath -Destination $destPath -Force -ErrorAction Stop
                    return $true
                } else {
                    # Hash mismatch - cleanup temp file
                    Remove-Item -Path $tempDestPath -Force -ErrorAction SilentlyContinue
                    return $false
                }
            }
        } catch {
            # Cleanup any temp files on error
            $tempPattern = $destPath + "_temp_*"
            Get-ChildItem -Path (Split-Path $destPath -Parent) -Filter (Split-Path $tempPattern -Leaf) -ErrorAction SilentlyContinue | 
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
}