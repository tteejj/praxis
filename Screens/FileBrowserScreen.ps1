# FileBrowserScreen - File browser using FastFileTree component
# Proper PRAXIS architecture implementation

class FileBrowserScreen : Screen {
    [RangerFileTree]$FileTree
    [scriptblock]$FileSelectedCallback = $null  # Callback for file selection
    
    FileBrowserScreen() : base() {
        $this.Title = "File Browser - [h/←]Back [j/↓]Down [k/↑]Up [l/→]Enter [y]Yank [d]Cut [p]Paste [r]Rename [D]Delete [Space]Mark"
    }
    
    [void] OnInitialize() {
        # Get configuration service
        $configService = $this.ServiceContainer.GetService("ConfigurationService")
        $defaultPath = (Get-Location).Path
        
        if ($configService) {
            # Load file browser settings
            $fbConfig = $configService.Get("FileBrowser")
            if ($fbConfig -and $fbConfig.ContainsKey("DefaultPath") -and $fbConfig.DefaultPath) {
                $defaultPath = $fbConfig.DefaultPath
            }
        }
        
        # Create and configure the ranger-style file tree
        $this.FileTree = [RangerFileTree]::new()
        $this.FileTree.CurrentPath = $defaultPath
        # Add the file tree as a child component BEFORE initializing
        # This ensures Parent is set correctly
        $this.AddChild($this.FileTree)
        
        # Initialize the FileTree with the service container
        $this.FileTree.Initialize($this.ServiceContainer)
        
        # Apply file browser settings
        $this.ApplyFileBrowserSettings()
        
        # Subscribe to configuration changes
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus) {
            $screen = $this
            $eventBus.Subscribe([EventNames]::ConfigChanged, {
                param($sender, $eventData)
                if ($eventData.Path -match "^FileBrowser\.") {
                    $screen.ApplyFileBrowserSettings()
                }
            }.GetNewClosure())
        }
        
        # Set up event handlers
        $screen = $this  # Capture reference for closures
        
        $this.FileTree.OnFileSelected = {
            param($node)
            if ($screen.FileSelectedCallback) {
                & $screen.FileSelectedCallback $node.FullPath
            } else {
                # Default behavior: open text editor for files
                $screen.OpenFileInEditor($node.FullPath)
            }
        }.GetNewClosure()
    }
    
    [void] OnBoundsChanged() {
        # Call base implementation
        ([Screen]$this).OnBoundsChanged()
        
        # Set the file tree to fill the entire screen
        if ($this.FileTree -and $this.Width -gt 0 -and $this.Height -gt 0) {
            $this.FileTree.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        } elseif ($global:Logger) {
            $global:Logger.Warning("FileBrowserScreen.OnBoundsChanged: Invalid bounds - FileTree=$($this.FileTree -ne $null), Width=$($this.Width), Height=$($this.Height)")
        }
    }
    
    [void] OpenFileInEditor([string]$filePath) {
        if (-not $filePath -or -not (Test-Path $filePath)) {
            return
        }
        
        $item = Get-Item $filePath -ErrorAction SilentlyContinue
        if ($item -and -not $item.PSIsContainer) {
            # It's a file, open in text editor
            try {
                $editorType = [type]"TextEditorScreen"
                if ($editorType) {
                    $editor = $editorType::new($filePath)
                    
                    # Get screen manager and push the editor
                    $screenManager = $this.ServiceContainer.GetService("ScreenManager")
                    $screenManager.Push($editor)
                }
            } catch {
                # TextEditorScreen not available
                if ($global:Logger) {
                    $global:Logger.Info("TextEditor not available for file: $filePath")
                }
            }
        }
    }
    
    # Override OnActivated to ensure FileTree gets focus
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Use FocusFirst to focus the first focusable child (should be FileTree)
        $this.FocusFirst()
        
        if ($global:Logger) {
            # Check what got focused
            $focusedChild = $this.FindFocusedChild()
            if ($focusedChild) {
                $global:Logger.Debug("  Focused child: $($focusedChild.GetType().Name)")
                $global:Logger.Debug("  Focused child IsFocused: $($focusedChild.IsFocused)")
            } else {
                $global:Logger.Debug("  No focused child found after FocusFirst()!")
                # Try direct focus as fallback
                if ($this.FileTree) {
                    $global:Logger.Debug("  Attempting direct FileTree.Focus()")
                    $this.FileTree.Focus()
                    # Check again
                    $focusedChild = $this.FindFocusedChild()
                    if ($focusedChild) {
                        $global:Logger.Debug("  After direct focus: Found $($focusedChild.GetType().Name)")
                    } else {                    }
                }
            }
        }
    }
    
    # Override HandleInput to debug input routing
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Call base implementation
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] NewFile() {
        # Create new file in current directory
        if ($this.FileTree -and $this.FileTree.CurrentPath) {
            $dialog = [TextInputDialog]::new("New File", "")
            $dialog.Title = "Create New File"
            $dialog.Prompt = "Enter filename:"
            
            $currentPath = $this.FileTree.CurrentPath
            $screen = $this
            $dialog.OnSubmit = {
                param($filename)
                if (-not [string]::IsNullOrWhiteSpace($filename)) {
                    $newFilePath = Join-Path $currentPath $filename
                    try {
                        New-Item -ItemType File -Path $newFilePath -Force | Out-Null
                        $screen.FileTree.RefreshCurrentDirectory()
                        
                        $toastService = $screen.ServiceContainer.GetService('ToastService')
                        if ($toastService) {
                            $toastService.Show("File created: $filename", [ToastType]::Success, 2000)
                        }
                    }
                    catch {
                        $toastService = $screen.ServiceContainer.GetService('ToastService')
                        if ($toastService) {
                            $toastService.Show("Failed to create file: $($_.Exception.Message)", [ToastType]::Error, 3000)
                        }
                    }
                }
            }.GetNewClosure()
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] EditFile() {
        # Edit selected file
        if ($this.FileTree -and $this.FileTree.SelectedNode) {
            $node = $this.FileTree.SelectedNode
            if (-not $node.IsDirectory -and $node.FullPath) {
                $this.OpenFileInEditor($node.FullPath)
            }
        }
    }
    
    [void] DeleteFile() {
        # Delete selected file/directory
        if ($this.FileTree -and $this.FileTree.SelectedNode) {
            $node = $this.FileTree.SelectedNode
            $itemType = if ($node.IsDirectory) { "directory" } else { "file" }
            $nodeName = $node.Name
            $message = "Are you sure you want to delete this ${itemType}?`n`n${nodeName}"
            
            $dialog = [ConfirmationDialog]::new($message)
            $dialog.Title = "Delete $itemType"
            
            $screen = $this
            $fullPath = $node.FullPath
            $dialog.OnPrimary = {
                try {
                    Remove-Item -Path $fullPath -Recurse -Force
                    $screen.FileTree.RefreshCurrentDirectory()
                    
                    $toastService = $screen.ServiceContainer.GetService('ToastService')
                    if ($toastService) {
                        $toastService.Show("Deleted: $nodeName", [ToastType]::Success, 2000)
                    }
                }
                catch {
                    $toastService = $screen.ServiceContainer.GetService('ToastService')
                    if ($toastService) {
                        $toastService.Show("Failed to delete: $($_.Exception.Message)", [ToastType]::Error, 3000)
                    }
                }
            }.GetNewClosure()
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] RefreshFiles() {
        # Refresh current directory
        if ($this.FileTree) {
            $this.FileTree.RefreshCurrentDirectory()
            
            $toastService = $this.ServiceContainer.GetService('ToastService')
            if ($toastService) {
                $toastService.Show("Files refreshed", [ToastType]::Info, 1000)
            }
        }
    }
    
    [void] ApplyFileBrowserSettings() {
        $configService = $this.ServiceContainer.GetService("ConfigurationService")
        if (-not $configService -or -not $this.FileTree) { return }
        
        $fbConfig = $configService.Get("FileBrowser")
        if ($fbConfig) {
            # TODO: Apply ShowHiddenFiles setting when RangerFileTree supports it
            # if ($fbConfig.ContainsKey("ShowHiddenFiles")) {
            #     $this.FileTree.ShowHiddenFiles = [bool]$fbConfig.ShowHiddenFiles
            # }
            
            # TODO: Apply sort settings when RangerFileTree supports them
            # Note: Current RangerFileTree may not support these settings yet
            
            # For now, just refresh the tree
            if ($this.FileTree.RefreshView) {
                $this.FileTree.RefreshView()
            }
            $this.FileTree.Invalidate()
        }
    }
}