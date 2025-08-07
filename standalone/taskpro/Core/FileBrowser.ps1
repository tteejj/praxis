# FileBrowser.ps1 - Cross-platform file/folder selection

class FileBrowser {
    static [string] ShowFolderBrowser([string]$title, [string]$initialDir = "") {
        # Console input for cross-platform compatibility
        Write-Host "$title" -ForegroundColor Yellow
        if ($initialDir) {
            Write-Host "Current: $initialDir" -ForegroundColor Gray
        }
        Write-Host "Enter folder path (or press Enter to cancel): " -NoNewline
        $path = Read-Host
        if ($path -and (Test-Path $path)) {
            return $path
        }
        return ""
    }
    
    static [string] ShowFileBrowser([string]$title, [string]$filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*", [string]$initialDir = "") {
        # Console input for cross-platform compatibility
        Write-Host "$title" -ForegroundColor Yellow
        if ($initialDir) {
            Write-Host "Initial directory: $initialDir" -ForegroundColor Gray
        }
        Write-Host "Enter file path (or press Enter to cancel): " -NoNewline
        $path = Read-Host
        if ($path -and (Test-Path $path)) {
            return $path
        }
        return ""
    }
}