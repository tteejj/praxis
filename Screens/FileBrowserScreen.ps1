# FileBrowserScreen - File browser using FastFileTree component
# Proper PRAXIS architecture implementation

class FileBrowserScreen : Screen {
    [RangerFileTree]$FileTree
    [scriptblock]$FileSelectedCallback = $null  # Callback for file selection
    
    FileBrowserScreen() : base() {
        $this.Title = "File Browser"
    }
    
    [void] OnInitialize() {
        # Create and configure the ranger-style file tree
        $this.FileTree = [RangerFileTree]::new()
        $this.FileTree.CurrentPath = (Get-Location).Path
        
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
    
    # Override OnActivated to ensure FileTree gets focus
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        if ($this.FileTree) {
            $this.FileTree.Focus()
        }
    }
}