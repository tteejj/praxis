#!/usr/bin/env pwsh
# Create test time entries for current week

# Get current week Friday
$today = [DateTime]::Today
$daysUntilFriday = ([int][DayOfWeek]::Friday - [int]$today.DayOfWeek + 7) % 7
if ($daysUntilFriday -eq 0 -and $today.DayOfWeek -ne [DayOfWeek]::Friday) {
    $daysUntilFriday = 7
}
$friday = $today.AddDays($daysUntilFriday)
$weekString = $friday.ToString("yyyyMMdd")

Write-Host "Creating time entries for week ending $($friday.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan

# Load existing data
$dataFile = "_ProjectData/timeentries.json"
$data = if (Test-Path $dataFile) {
    Get-Content $dataFile -Raw | ConvertFrom-Json
} else {
    @{
        TimeEntries = @()
        TimeCodes = @()
        LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add some test time codes if they don't exist
$testCodes = @(
    @{ID2 = "ADMIN"; Name = "Administration"; ID1 = "Internal"; Description = "Administrative tasks"; IsActive = $true}
    @{ID2 = "TRAIN"; Name = "Training"; ID1 = "Internal"; Description = "Training and learning"; IsActive = $true}
    @{ID2 = "MEET"; Name = "Meetings"; ID1 = "Internal"; Description = "Team meetings"; IsActive = $true}
)

foreach ($code in $testCodes) {
    if (-not ($data.TimeCodes | Where-Object { $_.ID2 -eq $code.ID2 })) {
        $code.CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $data.TimeCodes += $code
    }
}

# Add test entries for current week
$entries = @(
    @{
        Id = "TE-$weekString-ADMIN"
        WeekEndingFriday = $weekString
        Name = "Administration"
        ID1 = "Internal"
        ID2 = "ADMIN"
        Monday = 2.5
        Tuesday = 3.0
        Wednesday = 2.0
        Thursday = 1.5
        Friday = 1.0
        Total = 10.0
        FiscalYear = "$((Get-Date).Year)-$((Get-Date).Year + 1)"
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        UpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    },
    @{
        Id = "TE-$weekString-TRAIN"
        WeekEndingFriday = $weekString
        Name = "Training"
        ID1 = "Internal"
        ID2 = "TRAIN"
        Monday = 1.0
        Tuesday = 1.5
        Wednesday = 2.0
        Thursday = 1.0
        Friday = 0.5
        Total = 6.0
        FiscalYear = "$((Get-Date).Year)-$((Get-Date).Year + 1)"
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        UpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
)

# Remove old entries for this week
$data.TimeEntries = $data.TimeEntries | Where-Object { $_.WeekEndingFriday -ne $weekString }

# Add new entries
foreach ($entry in $entries) {
    $data.TimeEntries += $entry
}

# Update timestamp
$data.LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Save back to file
$data | ConvertTo-Json -Depth 10 | Set-Content $dataFile -Encoding UTF8

Write-Host "Created $($entries.Count) time entries" -ForegroundColor Green
Write-Host "Total entries in file: $($data.TimeEntries.Count)" -ForegroundColor Yellow