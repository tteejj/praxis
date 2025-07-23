# FileBrowserScreen - File browser using FastFileTree component
# Proper PRAXIS architecture implementation

class FileBrowserScreen : Screen {
    [FastFileTree]$FileTree
    [scriptblock]$FileSelectedCallback = $null  # Callback for file selection
    
    FileBrowserScreen() : base() {
        $this.Title = "File Browser"
    }
    
    [void] OnInitialize() {
        # Create and configure the file tree
        $this.FileTree = [FastFileTree]::new()
        $this.FileTree.ShowBorder = $true
        $this.FileTree.Title = "Files"
        $this.FileTree.ShowSize = $true
        
        # Add as child so it gets initialized properly
        $this.AddChild($this.FileTree)
        
        # Start with current directory
        $this.FileTree.LoadDirectory((Get-Location).Path)
        
        # Set up event handlers
        $screen = $this  # Capture reference for closures
        
        $this.FileTree.OnFileSelected = {
            param($filePath)
            if ($screen.FileSelectedCallback) {
                & $screen.FileSelectedCallback $filePath
            } else {
                # Default behavior: open text editor for files
                $screen.OpenFileInEditor($filePath)
            }
        }.GetNewClosure()
        
        $this.FileTree.OnSelectionChanged = {
            # Could add status bar updates here if needed
        }.GetNewClosure()
        
        # Add the file tree as a child component
        $this.AddChild($this.FileTree)
    }
    
    [void] OnBoundsChanged() {
        # Set the file tree to fill the entire screen
        if ($this.FileTree) {
            $this.FileTree.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
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
    
    # Override HandleScreenInput to add custom file browser shortcuts
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle custom file browser shortcuts
        if ($keyInfo.KeyChar) {
            switch ($keyInfo.KeyChar) {
                'e' { 
                    # Edit selected file
                    $selected = $this.FileTree.GetSelectedNode()
                    if ($selected -and -not $selected.IsDirectory) {
                        $this.OpenFileInEditor($selected.FullPath)
                        return $true
                    }
                }
                'v' { 
                    # View selected file (same as edit for now)
                    $selected = $this.FileTree.GetSelectedNode()
                    if ($selected -and -not $selected.IsDirectory) {
                        $this.OpenFileInEditor($selected.FullPath)
                        return $true
                    }
                }
                'u' {
                    # Go up one directory
                    $this.FileTree.NavigateUp()
                    return $true
                }
            }
        }
        
        # Let the base class handle other input (like tab switching)
        return $false
    }
}