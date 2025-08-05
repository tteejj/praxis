#!/usr/bin/env pwsh
# migrate-to-unified-data.ps1 - One-time migration to consolidated data structure

Write-Host "Praxis Data Migration to Unified Structure" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Safety check
Write-Host "This will consolidate data from:" -ForegroundColor Yellow
Write-Host "  • TaskPro/Data/" -ForegroundColor White
Write-Host "  • TaskPro/_ProjectData/" -ForegroundColor White  
Write-Host "Into unified: TaskPro/_ProjectData/praxis-unified.json" -ForegroundColor White
Write-Host ""
Write-Host "Original files will be backed up to migration-backup/ folder" -ForegroundColor Green
Write-Host ""

if ($args -contains "-auto") {
    $confirm = "y"
    Write-Host "Auto-migration mode enabled" -ForegroundColor Green
} else {
    $confirm = Read-Host "Continue with migration? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Migration cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Load PraxisDataService
try {
    . "$PSScriptRoot/TaskPro/Services/PraxisDataService.ps1"
    Write-Host "✓ PraxisDataService loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load PraxisDataService: $_" -ForegroundColor Red
    exit 1
}

# Create backup directory for original files
$backupDir = Join-Path $PSScriptRoot "migration-backup"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$migrationBackup = Join-Path $backupDir "migration_$timestamp"
New-Item -ItemType Directory -Path $migrationBackup -Force | Out-Null

Write-Host ""
Write-Host "Step 1: Backing up original files..." -ForegroundColor Yellow

# Backup TaskPro data
$taskProData = Join-Path $PSScriptRoot "TaskPro/Data"
if (Test-Path $taskProData) {
    $taskProBackup = Join-Path $migrationBackup "TaskPro_Data"
    Copy-Item $taskProData $taskProBackup -Recurse -Force
    Write-Host "  ✓ TaskPro/Data backed up" -ForegroundColor Green
}

# Backup _ProjectData
$projectData = Join-Path $PSScriptRoot "TaskPro/_ProjectData"
if (Test-Path $projectData) {
    $projectDataBackup = Join-Path $migrationBackup "_ProjectData"
    Copy-Item $projectData $projectDataBackup -Recurse -Force
    Write-Host "  ✓ TaskPro/_ProjectData backed up" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 2: Loading existing data..." -ForegroundColor Yellow

# Initialize unified data structure
$unifiedData = @{
    metadata = @{
        version = "1.0.0"
        created = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        lastModified = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        description = "Praxis unified data - migrated from separate files"
        migrationDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    projects = @()
    tasks = @()
    timeEntries = @()
    commands = @()
    themes = @{
        current = "default"
        settings = @{}
    }
    appStates = @{
        taskpro = @{
            selectedTaskId = $null
            scrollPosition = 0
        }
        timetracker = @{
            currentWeek = (Get-Date).ToString("yyyyMMdd")
            selectedEntry = $null
        }
        commandlibrary = @{
            lastSearch = ""
            selectedCommand = $null
        }
    }
}

# Load TaskPro projects
$taskProProjectsFile = Join-Path $PSScriptRoot "TaskPro/Data/projects.json"
if (Test-Path $taskProProjectsFile) {
    try {
        $taskProProjects = Get-Content $taskProProjectsFile -Raw | ConvertFrom-Json
        $unifiedData.projects = $taskProProjects
        Write-Host "  ✓ Loaded $($taskProProjects.Count) TaskPro projects" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to load TaskPro projects: $_" -ForegroundColor Red
    }
}

# Load TaskPro tasks
$taskProTasksFile = Join-Path $PSScriptRoot "TaskPro/Data/tasks.json"
if (Test-Path $taskProTasksFile) {
    try {
        $taskProTasks = Get-Content $taskProTasksFile -Raw | ConvertFrom-Json
        $unifiedData.tasks = $taskProTasks
        Write-Host "  ✓ Loaded $($taskProTasks.Count) TaskPro tasks" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to load TaskPro tasks: $_" -ForegroundColor Red
    }
}

# Load TaskPro themes
$taskProThemesFile = Join-Path $PSScriptRoot "TaskPro/Data/theme-settings.json"
if (Test-Path $taskProThemesFile) {
    try {
        $taskProThemes = Get-Content $taskProThemesFile -Raw | ConvertFrom-Json
        $unifiedData.themes = $taskProThemes
        Write-Host "  ✓ Loaded TaskPro theme settings" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to load TaskPro themes: $_" -ForegroundColor Red
    }
}

# Load TimeTracker data
$timeEntriesFile = Join-Path $PSScriptRoot "TaskPro/_ProjectData/timeentries.json"
if (Test-Path $timeEntriesFile) {
    try {
        $timeEntries = Get-Content $timeEntriesFile -Raw | ConvertFrom-Json
        $unifiedData.timeEntries = $timeEntries
        Write-Host "  ✓ Loaded $($timeEntries.Count) time entries" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to load time entries: $_" -ForegroundColor Red
    }
}

# Check for TimeTracker tasks (might conflict with TaskPro tasks)
$timeTrackerTasksFile = Join-Path $PSScriptRoot "TaskPro/_ProjectData/tasks.json"
if (Test-Path $timeTrackerTasksFile) {
    try {
        $timeTrackerTasks = Get-Content $timeTrackerTasksFile -Raw | ConvertFrom-Json
        Write-Host "  ! Found TimeTracker tasks.json - merging with TaskPro tasks" -ForegroundColor Yellow
        
        # Simple merge - add TimeTracker tasks that don't exist in TaskPro
        $taskProTaskIds = $unifiedData.tasks | ForEach-Object { $_.Id }
        foreach ($ttTask in $timeTrackerTasks) {
            if ($ttTask.Id -notin $taskProTaskIds) {
                $unifiedData.tasks += $ttTask
                Write-Host "    Added TimeTracker task: $($ttTask.Title)" -ForegroundColor DarkGreen
            }
        }
        Write-Host "  ✓ Merged TimeTracker tasks (total: $($unifiedData.tasks.Count))" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to merge TimeTracker tasks: $_" -ForegroundColor Red
    }
}

# Load CommandLibrary data
$commandsFile = Join-Path $PSScriptRoot "TaskPro/_ProjectData/commands.json"
if (Test-Path $commandsFile) {
    try {
        $commands = Get-Content $commandsFile -Raw | ConvertFrom-Json
        $unifiedData.commands = $commands
        Write-Host "  ✓ Loaded $($commands.Count) commands" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to load commands: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Step 3: Creating unified data file..." -ForegroundColor Yellow

# Initialize PraxisDataService and save unified data
try {
    $dataPath = Join-Path $PSScriptRoot "TaskPro/_ProjectData"
    [PraxisDataService]::Initialize($dataPath)
    
    # Set the loaded data
    [PraxisDataService]::CachedData = $unifiedData
    [PraxisDataService]::DataLoaded = $true
    
    # Save unified data
    [PraxisDataService]::SaveData("Initial migration")
    
    Write-Host "  ✓ Unified data file created: TaskPro/_ProjectData/praxis-unified.json" -ForegroundColor Green
    
} catch {
    Write-Host "  ✗ Failed to create unified data: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 4: Migration summary..." -ForegroundColor Yellow
Write-Host "  Projects: $($unifiedData.projects.Count)" -ForegroundColor White
Write-Host "  Tasks: $($unifiedData.tasks.Count)" -ForegroundColor White
Write-Host "  Time Entries: $($unifiedData.timeEntries.Count)" -ForegroundColor White
Write-Host "  Commands: $($unifiedData.commands.Count)" -ForegroundColor White
Write-Host "  Themes: $(if ($unifiedData.themes.settings) { 'Migrated' } else { 'Default' })" -ForegroundColor White

Write-Host ""
Write-Host "Migration completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Original files backed up to: $migrationBackup" -ForegroundColor Green
Write-Host "Unified data file: TaskPro/_ProjectData/praxis-unified.json" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the unified data with the updated apps" -ForegroundColor White
Write-Host "2. If everything works, you can delete the original data files" -ForegroundColor White
Write-Host "3. The migration backup will remain for safety" -ForegroundColor White

# Offer to create a test script
Write-Host ""
$createTest = Read-Host "Create test script to verify unified data? (y/N)"
if ($createTest -eq "y" -or $createTest -eq "Y") {
    $testScript = @"
#!/usr/bin/env pwsh
# test-unified-data.ps1 - Test unified data structure

. "`$PSScriptRoot/TaskPro/Services/PraxisDataService.ps1"

try {
    [PraxisDataService]::Initialize("`$PSScriptRoot/TaskPro/_ProjectData")
    
    `$data = [PraxisDataService]::GetData()
    
    Write-Host "Unified Data Test Results:" -ForegroundColor Cyan
    Write-Host "  Projects: `$(`$data.projects.Count)" -ForegroundColor Green
    Write-Host "  Tasks: `$(`$data.tasks.Count)" -ForegroundColor Green
    Write-Host "  Time Entries: `$(`$data.timeEntries.Count)" -ForegroundColor Green
    Write-Host "  Commands: `$(`$data.commands.Count)" -ForegroundColor Green
    Write-Host "  Metadata Version: `$(`$data.metadata.version)" -ForegroundColor Green
    Write-Host ""
    Write-Host "✓ Unified data loads successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Failed to load unified data: `$_" -ForegroundColor Red
    exit 1
}
"@
    
    Set-Content -Path "$PSScriptRoot/test-unified-data.ps1" -Value $testScript -Encoding UTF8
    Write-Host "✓ Created test-unified-data.ps1" -ForegroundColor Green
}

Write-Host ""