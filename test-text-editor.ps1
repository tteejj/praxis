#!/usr/bin/env pwsh
# Test the text editor fixes

Write-Host "Text Editor Test Instructions" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will launch the text editor. Test the following:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. SELECT ALL + DELETE:" -ForegroundColor Green
Write-Host "   - Press Ctrl+A to select all text" 
Write-Host "   - Press Delete or Backspace to delete all selected text"
Write-Host "   - The text should be deleted"
Write-Host ""
Write-Host "2. UNDO/REDO:" -ForegroundColor Green
Write-Host "   - After deleting, press Ctrl+Z to undo"
Write-Host "   - Text should reappear"
Write-Host "   - Press Ctrl+Y to redo" 
Write-Host "   - Text should be deleted again"
Write-Host ""
Write-Host "3. TEXT OPERATIONS:" -ForegroundColor Green
Write-Host "   - Type some text"
Write-Host "   - Select text with Shift+Arrow keys"
Write-Host "   - Copy (Ctrl+C), Cut (Ctrl+X), Paste (Ctrl+V)"
Write-Host "   - All operations should support undo/redo"
Write-Host ""
Write-Host "4. EXIT:" -ForegroundColor Green
Write-Host "   - Press Q or Escape to exit the editor"
Write-Host ""
Write-Host "Press any key to start the test..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Launch the editor
& ./Start.ps1