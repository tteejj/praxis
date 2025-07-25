# FileBrowserScreen - File browser using FastFileTree component
# Proper PRAXIS architecture implementation

class FileBrowserScreen : Screen {
    [RangerFileTree]$FileTree
    [scriptblock]$FileSelectedCallback = $null  # Callback for file selection
    
    FileBrowserScreen() : base() {
        $this.Title = "File Browser - [h/←]Back [j/↓]Down [k/↑]Up [l/→]Enter [.]Hidden"
    }
    
    [void] OnInitialize() {
        if ($global:Logger) {
            $global:Logger.Debug("FileBrowserScreen.OnInitialize: Starting initialization")
        }
        
        # Create and configure the ranger-style file tree
        $this.FileTree = [RangerFileTree]::new()
        $this.FileTree.CurrentPath = (Get-Location).Path
        
        if ($global:Logger) {
            $global:Logger.Debug("FileBrowserScreen: Created RangerFileTree with path: $($this.FileTree.CurrentPath)")
            $global:Logger.Debug("FileBrowserScreen: FileTree IsFocusable: $($this.FileTree.IsFocusable)")
        }
        
        # Add the file tree as a child component BEFORE initializing
        # This ensures Parent is set correctly
        $this.AddChild($this.FileTree)
        
        # Initialize the FileTree with the service container
        $this.FileTree.Initialize($this.ServiceContainer)
        
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
        
        if ($global:Logger) {
            $global:Logger.Debug("FileBrowserScreen.OnInitialize: Completed, Children.Count=$($this.Children.Count)")
        }
    }
    
    [void] OnBoundsChanged() {
        # Call base implementation
        ([Screen]$this).OnBoundsChanged()
        
        # Set the file tree to fill the entire screen
        if ($this.FileTree -and $this.Width -gt 0 -and $this.Height -gt 0) {
            $this.FileTree.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
            
            if ($global:Logger) {
                $global:Logger.Debug("FileBrowserScreen.OnBoundsChanged: Set FileTree bounds to ($($this.X),$($this.Y),$($this.Width),$($this.Height))")
            }
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
        
        if ($global:Logger) {
            $global:Logger.Debug("FileBrowserScreen.OnActivated: Screen activated")
            $global:Logger.Debug("  Children.Count = $($this.Children.Count)")
        }
        
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
                    } else {
                        $global:Logger.Debug("  Still no focused child!")
                    }
                }
            }
        }
    }
    
    # Override HandleInput to debug input routing
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("FileBrowserScreen.HandleInput: Key=$($key.Key) Char='$($key.KeyChar)'")
            $global:Logger.Debug("  FileTree.IsFocused = $($this.FileTree.IsFocused)")
        }
        
        # Call base implementation
        return ([Screen]$this).HandleInput($key)
    }
}