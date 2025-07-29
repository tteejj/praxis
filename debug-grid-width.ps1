#!/usr/bin/env pwsh

Write-Host "Grid Width Debug" -ForegroundColor Yellow
Write-Host "================" -ForegroundColor Yellow

# Calculate expected width for Time Entry grid
$columns = @(
    @{Name="Name"; Width=30},
    @{Name="ID1"; Width=10},
    @{Name="ID2"; Width=15},
    @{Name="Mon"; Width=6},
    @{Name="Tue"; Width=6},
    @{Name="Wed"; Width=6},
    @{Name="Thu"; Width=6},
    @{Name="Fri"; Width=6},
    @{Name="Total"; Width=7}
)

Write-Host "`nColumn widths:"
$totalColumnWidth = 0
foreach ($col in $columns) {
    Write-Host "  $($col.Name): $($col.Width)"
    $totalColumnWidth += $col.Width
}

Write-Host "`nWidth calculations:"
Write-Host "  Total column width: $totalColumnWidth"
Write-Host "  Column separators: $($columns.Count - 1)"
Write-Host "  Selection indicator: 3"
Write-Host "  Total content width needed: $($totalColumnWidth + $columns.Count - 1 + 3)"

Write-Host "`nWith border:"
$borderWidth = 2
Write-Host "  Border width: $borderWidth"
Write-Host "  Total width needed: $($totalColumnWidth + $columns.Count - 1 + 3 + $borderWidth)"

Write-Host "`nTypical terminal widths:"
Write-Host "  80 columns: Too narrow (missing columns)"
Write-Host "  120 columns: Should fit all columns"

Write-Host "`nIssue Analysis:" -ForegroundColor Cyan
Write-Host "The separator line extends too far because:"
Write-Host "1. It's calculating for all columns even if they don't fit on screen"
Write-Host "2. The grid is not properly truncating columns that overflow"
Write-Host "3. The Friday column is being cut off in display but included in separator calculation"