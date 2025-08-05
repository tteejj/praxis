#!/usr/bin/env pwsh
# Test script to debug TaskPro layout

$width = [Console]::WindowWidth
$height = [Console]::WindowHeight
$listWidth = 40
$editorX = $listWidth
$editorWidth = $width - $listWidth

Write-Host "Console dimensions: ${width}x${height}" -ForegroundColor Cyan
Write-Host "List width: $listWidth" -ForegroundColor Yellow
Write-Host "Editor X: $editorX" -ForegroundColor Yellow
Write-Host "Editor width: $editorWidth" -ForegroundColor Yellow

# Draw test borders
[Console]::Clear()

# Top border
[Console]::SetCursorPosition(0, 0)
Write-Host -NoNewline ("┌" + ("─" * ($listWidth - 2)) + "┬" + ("─" * ($editorWidth - 2)) + "┐")

# Test content in each panel
[Console]::SetCursorPosition(2, 1)
Write-Host -NoNewline "TASKS"

[Console]::SetCursorPosition($editorX + 2, 1)
Write-Host -NoNewline "EDITOR"

# Middle separator
for ($y = 1; $y -lt $height - 1; $y++) {
    [Console]::SetCursorPosition($listWidth - 1, $y)
    Write-Host -NoNewline "│"
}

# Test task line
[Console]::SetCursorPosition(2, 3)
Write-Host -NoNewline " ☐ Test task title here"

[Console]::SetCursorPosition($editorX + 2, 3)
Write-Host -NoNewline "Editor content here..."

# Bottom
[Console]::SetCursorPosition(0, $height - 1)
Write-Host -NoNewline ("└" + ("─" * ($listWidth - 2)) + "┴" + ("─" * ($editorWidth - 2)) + "┘")

[Console]::SetCursorPosition(0, $height)