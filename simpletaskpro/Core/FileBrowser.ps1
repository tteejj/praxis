# FileBrowser.ps1 - Cross-platform file/folder selection with native Windows dialogs

class FileBrowser {
    static [string] ShowFolderBrowser([string]$title, [string]$initialDir = "") {
        if ($env:OS -eq "Windows_NT" -or [System.Environment]::OSVersion.Platform -eq "Win32NT") {
            # Try Windows native dialog first
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderBrowser.Description = $title
                if ($initialDir -and (Test-Path $initialDir)) {
                    $folderBrowser.SelectedPath = $initialDir
                }
                
                $result = $folderBrowser.ShowDialog()
                if ($result -eq "OK") {
                    return $folderBrowser.SelectedPath
                }
                return ""
            } catch {
                # Fallback to console input
                return [FileBrowser]::ShowFolderBrowserConsole($title, $initialDir)
            }
        } else {
            # Linux/Mac - use console input
            return [FileBrowser]::ShowFolderBrowserConsole($title, $initialDir)
        }
    }
    
    static [string] ShowFileBrowser([string]$title, [string]$filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*", [string]$initialDir = "") {
        if ($env:OS -eq "Windows_NT" -or [System.Environment]::OSVersion.Platform -eq "Win32NT") {
            # Try Windows native dialog first
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
                $fileBrowser.Title = $title
                $fileBrowser.Filter = $filter
                if ($initialDir -and (Test-Path $initialDir)) {
                    $fileBrowser.InitialDirectory = $initialDir
                }
                
                $result = $fileBrowser.ShowDialog()
                if ($result -eq "OK") {
                    return $fileBrowser.FileName
                }
                return ""
            } catch {
                # Fallback to console input
                return [FileBrowser]::ShowFileBrowserConsole($title, $initialDir)
            }
        } else {
            # Linux/Mac - use console input
            return [FileBrowser]::ShowFileBrowserConsole($title, $initialDir)
        }
    }
    
    # Console-based folder selection (cross-platform fallback)
    static [string] ShowFolderBrowserConsole([string]$title, [string]$initialDir = "") {
        [Console]::Clear()
        Write-Host $title -ForegroundColor Yellow
        Write-Host ""
        
        if ($initialDir -and (Test-Path $initialDir)) {
            Write-Host "Current: $initialDir" -ForegroundColor Gray
        }
        
        Write-Host "Enter folder path (or press Enter to cancel): " -NoNewline
        $path = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($path)) {
            return ""
        }
        
        # Expand ~ to home directory on Linux/Mac
        if ($path.StartsWith("~") -and $env:HOME) {
            $path = $path -replace "^~", $env:HOME
        }
        
        if (Test-Path $path -PathType Container) {
            return (Resolve-Path $path).Path
        } else {
            Write-Host "Invalid folder path. Press any key to continue..." -ForegroundColor Red
            [Console]::ReadKey($true) | Out-Null
            return ""
        }
    }
    
    # Console-based file selection (cross-platform fallback)
    static [string] ShowFileBrowserConsole([string]$title, [string]$initialDir = "") {
        [Console]::Clear()
        Write-Host $title -ForegroundColor Yellow
        Write-Host ""
        
        if ($initialDir -and (Test-Path $initialDir)) {
            Write-Host "Initial directory: $initialDir" -ForegroundColor Gray
        }
        
        Write-Host "Enter file path (or press Enter to cancel): " -NoNewline
        $path = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($path)) {
            return ""
        }
        
        # Expand ~ to home directory on Linux/Mac
        if ($path.StartsWith("~") -and $env:HOME) {
            $path = $path -replace "^~", $env:HOME
        }
        
        if (Test-Path $path -PathType Leaf) {
            return (Resolve-Path $path).Path
        } else {
            Write-Host "Invalid file path. Press any key to continue..." -ForegroundColor Red
            [Console]::ReadKey($true) | Out-Null
            return ""
        }
    }
}