# Load-ModalSystem.ps1 - Load modal chording system classes in correct order

# Load core classes first
. "$PSScriptRoot/Core/ModalChordingEngine.ps1"
. "$PSScriptRoot/Core/CommandPalette.ps1"
. "$PSScriptRoot/Core/ClipboardManager.ps1"

Write-Host "Modal chording system loaded successfully" -ForegroundColor Green
Write-Host "Available features:" -ForegroundColor Cyan
Write-Host "  - Arrow key navigation (↑↓ for movement)" -ForegroundColor Gray
Write-Host "  - Chord combinations (gg, yy, pp, fa, ft, etc.)" -ForegroundColor Gray
Write-Host "  - Command palette (/ for commands)" -ForegroundColor Gray
Write-Host "  - Advanced clipboard operations" -ForegroundColor Gray
Write-Host "  - Status line with mode indicators" -ForegroundColor Gray