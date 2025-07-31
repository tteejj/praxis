# Comprehensive Pester tests for CommandService

$SpeedTUIRoot = Split-Path -Parent $PSScriptRoot
Set-Location $SpeedTUIRoot

BeforeAll {
    # Load dependencies with explicit paths
    . "./Core/Logger.ps1"
    . "./Models/BaseModel.ps1"
    . "./Models/Command.ps1"
    . "./Services/DataService.ps1"
    . "./Services/CommandService.ps1"
    
    # Create test data directory
    $SpeedTUIRoot = (Get-Location).Path
    $script:TestDataPath = Join-Path $SpeedTUIRoot "TestData"
    if (-not (Test-Path $script:TestDataPath)) {
        New-Item -Path $script:TestDataPath -ItemType Directory -Force
    }
}

Describe "CommandService Tests" {
    BeforeEach {
        # Create fresh service instance with test data path
        $script:service = [CommandService]::new()
        $script:service.DataDirectory = $script:TestDataPath
        $script:service.FileName = "test_commands"
        
        # Clear any existing test data
        $testFile = Join-Path $script:TestDataPath "test_commands.json"
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }
    }
    
    AfterEach {
        # Clean up test files
        $testFile = Join-Path $script:TestDataPath "test_commands.json"
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }
    }
    
    Context "Service Initialization" {
        It "Should initialize correctly" {
            $service = [CommandService]::new()
            
            $service | Should -Not -BeNull
            $service.FileName | Should -Be "commands"
            $service.DefaultGroups.Count | Should -BeGreaterThan 0
            $service.DefaultCategories.Count | Should -BeGreaterThan 0
        }
        
        It "Should have default groups and categories" {
            $script:service.DefaultGroups | Should -Contain "System"
            $script:service.DefaultGroups | Should -Contain "Development"
            $script:service.DefaultGroups | Should -Contain "PowerShell"
            
            $script:service.DefaultCategories | Should -Contain "Administration"
            $script:service.DefaultCategories | Should -Contain "Development"
            $script:service.DefaultCategories | Should -Contain "Utilities"
        }
    }
    
    Context "Command CRUD Operations" {
        It "Should create a valid command" {
            $commandData = @{
                Title = "Test Command"
                CommandText = "Get-Process"
                Description = "Test command description"
                Group = "Test"
                Category = "Testing"
            }
            
            $command = [Command]::new($commandData)
            $result = $script:service.Create($command)
            
            $result | Should -Not -BeNull
            $result.Title | Should -Be "Test Command"
            $result.CommandText | Should -Be "Get-Process"
            $result.IsValid() | Should -Be $true
        }
        
        It "Should retrieve command by ID" {
            $command = [Command]::new(@{
                Title = "Retrieve Test"
                CommandText = "Get-Service"
            })
            
            $created = $script:service.Create($command)
            $retrieved = $script:service.GetById($created.Id)
            
            $retrieved | Should -Not -BeNull
            $retrieved.Id | Should -Be $created.Id
            $retrieved.Title | Should -Be "Retrieve Test"
        }
        
        It "Should update existing command" {
            $command = [Command]::new(@{
                Title = "Original Title"
                CommandText = "Get-Date"
            })
            
            $created = $script:service.Create($command)
            $created.Title = "Updated Title"
            $created.Description = "Updated description"
            
            $updated = $script:service.Update($created)
            
            $updated.Title | Should -Be "Updated Title"
            $updated.Description | Should -Be "Updated description"
        }
        
        It "Should delete command (soft delete)" {
            $command = [Command]::new(@{
                Title = "Delete Test"
                CommandText = "Remove-Item"
            })
            
            $created = $script:service.Create($command)
            $script:service.Delete($created.Id)
            
            $retrieved = $script:service.GetById($created.Id)
            $retrieved | Should -BeNull
        }
        
        It "Should get all commands" {
            # Create multiple commands
            for ($i = 1; $i -le 3; $i++) {
                $command = [Command]::new(@{
                    Title = "Command $i"
                    CommandText = "Test-Command$i"
                })
                $script:service.Create($command) | Out-Null
            }
            
            $allCommands = $script:service.GetAll()
            $allCommands.Count | Should -Be 3
        }
    }
    
    Context "Search Functionality" {
        BeforeEach {
            # Create test commands with different properties
            $testCommands = @(
                @{
                    Title = "Git Status Check"
                    CommandText = "git status --porcelain"
                    Description = "Check git repository status"
                    Group = "Git"
                    Category = "Development"
                    Tags = @("git", "status", "vcs")
                },
                @{
                    Title = "System Process List"
                    CommandText = "Get-Process | Sort-Object CPU"
                    Description = "List system processes"
                    Group = "System"
                    Category = "Administration"
                    Tags = @("system", "process")
                },
                @{
                    Title = "Docker Container List"
                    CommandText = "docker ps -a"
                    Description = "List all docker containers"
                    Group = "Docker"
                    Category = "Development"
                    Tags = @("docker", "containers")
                }
            )
            
            foreach ($cmdData in $testCommands) {
                $command = [Command]::new($cmdData)
                $script:service.Create($command) | Out-Null
            }
        }
        
        It "Should search commands by text" {
            $results = $script:service.Search("git")
            
            $results.Count | Should -Be 1
            $results[0].Title | Should -Be "Git Status Check"
        }
        
        It "Should search commands by description" {
            $results = $script:service.Search("docker containers")
            
            $results.Count | Should -Be 1
            $results[0].Title | Should -Be "Docker Container List"
        }
        
        It "Should return all commands for empty search" {
            $results = $script:service.Search("")
            
            $results.Count | Should -Be 3
        }
        
        It "Should cache search results" {
            # First search
            $results1 = $script:service.Search("system")
            
            # Check cache was populated
            $script:service.SearchCache.ContainsKey("system") | Should -Be $true
            
            # Second search should use cache
            $results2 = $script:service.Search("system")
            
            $results1.Count | Should -Be $results2.Count
        }
    }
    
    Context "Filtering Operations" {
        BeforeEach {
            # Create test commands with different filters
            $testCommands = @(
                @{
                    Title = "PowerShell Command 1"
                    CommandText = "Get-ChildItem"
                    Group = "PowerShell"
                    Category = "File Management"
                    Language = "PowerShell"
                    Tags = @("files", "list")
                },
                @{
                    Title = "Git Command 1"
                    CommandText = "git commit -m 'message'"
                    Group = "Git"
                    Category = "Development"
                    Language = "Git"
                    Tags = @("git", "commit")
                },
                @{
                    Title = "PowerShell Command 2"
                    CommandText = "Get-Service"
                    Group = "PowerShell"
                    Category = "Administration"
                    Language = "PowerShell"
                    Tags = @("service", "system")
                }
            )
            
            foreach ($cmdData in $testCommands) {
                $command = [Command]::new($cmdData)
                $script:service.Create($command) | Out-Null
            }
        }
        
        It "Should filter by group" {
            $results = $script:service.FilterByGroup("PowerShell")
            
            $results.Count | Should -Be 2
            $results[0].Group | Should -Be "PowerShell"
            $results[1].Group | Should -Be "PowerShell"
        }
        
        It "Should filter by category" {
            $results = $script:service.FilterByCategory("Development")
            
            $results.Count | Should -Be 1
            $results[0].Category | Should -Be "Development"
        }
        
        It "Should filter by language" {
            $results = $script:service.FilterByLanguage("Git")
            
            $results.Count | Should -Be 1
            $results[0].Language | Should -Be "Git"
        }
        
        It "Should filter by tag" {
            $results = $script:service.FilterByTag("git")
            
            $results.Count | Should -Be 1
            $results[0].Tags | Should -Contain "git"
        }
        
        It "Should perform advanced search with multiple criteria" {
            $criteria = @{
                group = "PowerShell"
                category = "Administration"
            }
            
            $results = $script:service.AdvancedSearch($criteria)
            
            $results.Count | Should -Be 1
            $results[0].Group | Should -Be "PowerShell"
            $results[0].Category | Should -Be "Administration"
        }
    }
    
    Context "Command Organization" {
        BeforeEach {
            # Create commands with various organizational properties
            $testCommands = @(
                @{ Group = "Git"; Category = "Development"; Language = "Git"; Tags = @("git", "vcs") },
                @{ Group = "Docker"; Category = "Development"; Language = "Docker"; Tags = @("docker", "container") },
                @{ Group = "PowerShell"; Category = "Administration"; Language = "PowerShell"; Tags = @("system", "admin") },
                @{ Group = "PowerShell"; Category = "File Management"; Language = "PowerShell"; Tags = @("files", "admin") }
            )
            
            $i = 1
            foreach ($cmdData in $testCommands) {
                $cmdData.Title = "Test Command $i"
                $cmdData.CommandText = "Test-Command$i"
                $command = [Command]::new($cmdData)
                $script:service.Create($command) | Out-Null
                $i++
            }
        }
        
        It "Should get all groups" {
            $groups = $script:service.GetAllGroups()
            
            $groups | Should -Contain "Git"
            $groups | Should -Contain "Docker"
            $groups | Should -Contain "PowerShell"
            $groups.Count | Should -Be 3
        }
        
        It "Should get all categories" {
            $categories = $script:service.GetAllCategories()
            
            $categories | Should -Contain "Development"
            $categories | Should -Contain "Administration"
            $categories | Should -Contain "File Management"
            $categories.Count | Should -Be 3
        }
        
        It "Should get all languages" {
            $languages = $script:service.GetAllLanguages()
            
            $languages | Should -Contain "Git"
            $languages | Should -Contain "Docker"
            $languages | Should -Contain "PowerShell"
            $languages.Count | Should -Be 3
        }
        
        It "Should get all tags" {
            $tags = $script:service.GetAllTags()
            
            $tags | Should -Contain "git"
            $tags | Should -Contain "docker"
            $tags | Should -Contain "system"
            $tags | Should -Contain "admin"
            $tags.Count | Should -BeGreaterOrEqual 4
        }
        
        It "Should generate group summary" {
            $summary = $script:service.GetGroupSummary()
            
            $summary["PowerShell"] | Should -Be 2
            $summary["Git"] | Should -Be 1
            $summary["Docker"] | Should -Be 1
        }
    }
    
    Context "Usage Tracking" {
        BeforeEach {
            # Create test commands
            $command1 = [Command]::new(@{
                Title = "Frequently Used Command"
                CommandText = "Get-Process"
            })
            $script:cmd1 = $script:service.Create($command1)
            
            $command2 = [Command]::new(@{
                Title = "Rarely Used Command"
                CommandText = "Get-Service"
            })
            $script:cmd2 = $script:service.Create($command2)
            
            $command3 = [Command]::new(@{
                Title = "Never Used Command"
                CommandText = "Get-EventLog"
            })
            $script:cmd3 = $script:service.Create($command3)
        }
        
        It "Should record command usage" {
            # Record multiple uses of first command
            $script:service.RecordUsage($script:cmd1.Id)
            $script:service.RecordUsage($script:cmd1.Id)
            $script:service.RecordUsage($script:cmd1.Id)
            
            # Record single use of second command
            $script:service.RecordUsage($script:cmd2.Id)
            
            $updated1 = $script:service.GetById($script:cmd1.Id)
            $updated2 = $script:service.GetById($script:cmd2.Id)
            $updated3 = $script:service.GetById($script:cmd3.Id)
            
            $updated1.UseCount | Should -Be 3
            $updated2.UseCount | Should -Be 1
            $updated3.UseCount | Should -Be 0
            
            $updated1.LastUsed | Should -Not -Be ([DateTime]::MinValue)
            $updated2.LastUsed | Should -Not -Be ([DateTime]::MinValue)
            $updated3.LastUsed | Should -Be ([DateTime]::MinValue)
        }
        
        It "Should get most used commands" {
            # Set up usage counts
            $script:service.RecordUsage($script:cmd1.Id)
            $script:service.RecordUsage($script:cmd1.Id)
            $script:service.RecordUsage($script:cmd2.Id)
            
            $mostUsed = $script:service.GetMostUsedCommands(2)
            
            $mostUsed.Count | Should -Be 2
            $mostUsed[0].UseCount | Should -BeGreaterOrEqual $mostUsed[1].UseCount
        }
        
        It "Should get never used commands" {
            # Record usage for some commands
            $script:service.RecordUsage($script:cmd1.Id)
            
            $neverUsed = $script:service.GetNeverUsedCommands()
            
            $neverUsed.Count | Should -Be 2  # cmd2 and cmd3
            foreach ($cmd in $neverUsed) {
                $cmd.UseCount | Should -Be 0
            }
        }
        
        It "Should generate usage statistics" {
            # Set up some usage
            $script:service.RecordUsage($script:cmd1.Id)
            $script:service.RecordUsage($script:cmd1.Id)
            $script:service.RecordUsage($script:cmd2.Id)
            
            $stats = $script:service.GetUsageStatistics()
            
            $stats.TotalCommands | Should -Be 3
            $stats.UsedCommands | Should -Be 2
            $stats.NeverUsed | Should -Be 1
            $stats.TotalUsage | Should -Be 3
            $stats.AverageUsage | Should -Be 1.0
            $stats.UsageRate | Should -Be 66.7
        }
    }
    
    Context "Command Templates and Cloning" {
        BeforeEach {
            # Create a template command
            $templateData = @{
                Title = "Git Command Template"
                CommandText = "git {action} {parameters}"
                Description = "Template for git commands"
                Group = "Git"
                Category = "Development"
                Language = "Git"
                IsTemplate = $true
                Tags = @("git", "template")
            }
            
            $template = [Command]::new($templateData)
            $script:template = $script:service.Create($template)
            
            # Create a regular command for cloning
            $regularData = @{
                Title = "Regular Command"
                CommandText = "Get-Process"
                Description = "List processes"
                Group = "System"
                UseCount = 5
            }
            
            $regular = [Command]::new($regularData)
            $script:regular = $script:service.Create($regular)
        }
        
        It "Should get all templates" {
            $templates = $script:service.GetTemplates()
            
            $templates.Count | Should -Be 1
            $templates[0].IsTemplate | Should -Be $true
            $templates[0].Title | Should -Be "Git Command Template"
        }
        
        It "Should create command from template" {
            $customizations = @{
                Title = "Git Status Command"
                CommandText = "git status --porcelain"
                Description = "Check git status"
            }
            
            $newCommand = $script:service.CreateFromTemplate($script:template.Id, $customizations)
            
            $newCommand | Should -Not -BeNull
            $newCommand.Title | Should -Be "Git Status Command"
            $newCommand.CommandText | Should -Be "git status --porcelain"
            $newCommand.IsTemplate | Should -Be $false
            $newCommand.Group | Should -Be "Git"  # Inherited from template
            $newCommand.UseCount | Should -Be 0   # Reset for new command
        }
        
        It "Should clone existing command" {
            $customizations = @{
                Title = "Cloned Process Command"
                Description = "Modified process listing"
            }
            
            $clone = $script:service.CloneCommand($script:regular.Id, $customizations)
            
            $clone | Should -Not -BeNull
            $clone.Title | Should -Be "Cloned Process Command"
            $clone.CommandText | Should -Be "Get-Process"  # Inherited
            $clone.Group | Should -Be "System"             # Inherited
            $clone.UseCount | Should -Be 0                 # Reset for clone
            $clone.Id | Should -Not -Be $script:regular.Id # Different ID
        }
        
        It "Should throw error for invalid template ID" {
            {
                $script:service.CreateFromTemplate("invalid-id", @{})
            } | Should -Throw "Template not found: invalid-id"
        }
        
        It "Should throw error when using non-template as template" {
            {
                $script:service.CreateFromTemplate($script:regular.Id, @{})
            } | Should -Throw "Command is not a template*"
        }
    }
    
    Context "Quick Command Creation" {
        It "Should create quick command with minimal parameters" {
            $command = $script:service.CreateQuickCommand("Get-Date", "Current Date")
            
            $command | Should -Not -BeNull
            $command.Title | Should -Be "Current Date"
            $command.CommandText | Should -Be "Get-Date"
            $command.Group | Should -Be "General"
            $command.Language | Should -Be "PowerShell"
        }
        
        It "Should create quick command with just command text" {
            $command = $script:service.CreateQuickCommand("Get-Location")
            
            $command | Should -Not -BeNull
            $command.Title | Should -Be "Get-Location"
            $command.CommandText | Should -Be "Get-Location"
        }
        
        It "Should create command with full details" {
            $details = @{
                Title = "Detailed Command"
                CommandText = "Get-Service -Name 'Spooler'"
                Description = "Check printer spooler service"
                Group = "System"
                Category = "Administration"
                Language = "PowerShell"
                Tags = @("service", "printer")
            }
            
            $command = $script:service.CreateCommandWithDetails($details)
            
            $command | Should -Not -BeNull
            $command.Title | Should -Be "Detailed Command"
            $command.Description | Should -Be "Check printer spooler service"
            $command.Tags | Should -Contain "service"
            $command.Tags | Should -Contain "printer"
        }
        
        It "Should throw error for missing required fields" {
            $invalidDetails = @{
                Title = "Invalid Command"
                # Missing CommandText
            }
            
            {
                $script:service.CreateCommandWithDetails($invalidDetails)
            } | Should -Throw "Required field missing: CommandText"
        }
    }
    
    Context "Favorites Management" {
        BeforeEach {
            # Create test commands
            $command1 = [Command]::new(@{
                Title = "Command 1"
                CommandText = "Get-Process"
            })
            $script:cmd1 = $script:service.Create($command1)
            
            $command2 = [Command]::new(@{
                Title = "Command 2"
                CommandText = "Get-Service"
                Tags = @("favorite")  # Already a favorite
            })
            $script:cmd2 = $script:service.Create($command2)
        }
        
        It "Should add command to favorites" {
            $script:service.IsFavorite($script:cmd1.Id) | Should -Be $false
            
            $script:service.AddToFavorites($script:cmd1.Id)
            
            $script:service.IsFavorite($script:cmd1.Id) | Should -Be $true
        }
        
        It "Should remove command from favorites" {
            $script:service.IsFavorite($script:cmd2.Id) | Should -Be $true
            
            $script:service.RemoveFromFavorites($script:cmd2.Id)
            
            $script:service.IsFavorite($script:cmd2.Id) | Should -Be $false
        }
        
        It "Should get all favorite commands" {
            $script:service.AddToFavorites($script:cmd1.Id)
            
            $favorites = $script:service.GetFavorites()
            
            $favorites.Count | Should -Be 2  # cmd1 (newly added) + cmd2 (pre-existing)
            foreach ($fav in $favorites) {
                $fav.HasTag("favorite") | Should -Be $true
            }
        }
    }
    
    Context "Bulk Operations" {
        BeforeEach {
            # Create multiple test commands
            for ($i = 1; $i -le 5; $i++) {
                $command = [Command]::new(@{
                    Title = "Bulk Command $i"
                    CommandText = "Test-Command$i"
                    Group = "OldGroup"
                    Category = "OldCategory"
                    Tags = @("old")
                })
                $script:service.Create($command) | Out-Null
            }
        }
        
        It "Should bulk update group" {
            $allCommands = $script:service.GetAll()
            $commandIds = $allCommands | Select-Object -ExpandProperty Id
            
            $script:service.BulkUpdateGroup($commandIds, "NewGroup")
            
            $updatedCommands = $script:service.GetAll()
            foreach ($cmd in $updatedCommands) {
                $cmd.Group | Should -Be "NewGroup"
            }
        }
        
        It "Should bulk update category" {
            $allCommands = $script:service.GetAll()
            $commandIds = $allCommands | Select-Object -ExpandProperty Id
            
            $script:service.BulkUpdateCategory($commandIds, "NewCategory")
            
            $updatedCommands = $script:service.GetAll()
            foreach ($cmd in $updatedCommands) {
                $cmd.Category | Should -Be "NewCategory"
            }
        }
        
        It "Should bulk add tag" {
            $allCommands = $script:service.GetAll()
            $commandIds = $allCommands | Select-Object -ExpandProperty Id
            
            $script:service.BulkAddTag($commandIds, "newtag")
            
            $updatedCommands = $script:service.GetAll()
            foreach ($cmd in $updatedCommands) {
                $cmd.HasTag("newtag") | Should -Be $true
                $cmd.HasTag("old") | Should -Be $true  # Original tag preserved
            }
        }
        
        It "Should bulk remove tag" {
            $allCommands = $script:service.GetAll()
            $commandIds = $allCommands | Select-Object -ExpandProperty Id
            
            $script:service.BulkRemoveTag($commandIds, "old")
            
            $updatedCommands = $script:service.GetAll()
            foreach ($cmd in $updatedCommands) {
                $cmd.HasTag("old") | Should -Be $false
            }
        }
    }
    
    Context "Import/Export Operations" {
        It "Should export commands" {
            # Create test commands
            $command1 = [Command]::new(@{
                Title = "Export Test 1"
                CommandText = "Get-Process"
                Group = "TestGroup"
            })
            $script:service.Create($command1) | Out-Null
            
            $command2 = [Command]::new(@{
                Title = "Export Test 2"
                CommandText = "Get-Service"
                Group = "TestGroup"
            })
            $script:service.Create($command2) | Out-Null
            
            $exportData = $script:service.ExportCommands()
            
            $exportData.Count | Should -Be 2
            $exportData[0].Title | Should -Not -BeNullOrEmpty
            $exportData[0].CommandText | Should -Not -BeNullOrEmpty
        }
        
        It "Should export filtered commands" {
            # Create commands with different groups
            $command1 = [Command]::new(@{
                Title = "Group A Command"
                CommandText = "Get-Process"
                Group = "GroupA"
            })
            $script:service.Create($command1) | Out-Null
            
            $command2 = [Command]::new(@{
                Title = "Group B Command"
                CommandText = "Get-Service"
                Group = "GroupB"
            })
            $script:service.Create($command2) | Out-Null
            
            $exportData = $script:service.ExportCommands("group", "GroupA")
            
            $exportData.Count | Should -Be 1
            $exportData[0].Group | Should -Be "GroupA"
        }
        
        It "Should import commands" {
            $importData = @(
                @{
                    Title = "Imported Command 1"
                    CommandText = "Get-Date"
                    Group = "Import"
                    Category = "Test"
                },
                @{
                    Title = "Imported Command 2"
                    CommandText = "Get-Location"
                    Group = "Import"
                    Category = "Test"
                }
            )
            
            $script:service.ImportCommands($importData)
            
            $allCommands = $script:service.GetAll()
            $importedCommands = $allCommands | Where-Object { $_.Group -eq "Import" }
            
            $importedCommands.Count | Should -Be 2
            $importedCommands[0].Title | Should -Match "Imported Command"
            $importedCommands[1].Title | Should -Match "Imported Command"
        }
    }
    
    Context "Sorting and Pagination" {
        BeforeEach {
            # Create commands with different properties for sorting
            $commands = @(
                @{ Title = "ZZ Last"; UseCount = 1; LastUsed = [DateTime]::Now.AddDays(-1) },
                @{ Title = "AA First"; UseCount = 5; LastUsed = [DateTime]::Now },
                @{ Title = "MM Middle"; UseCount = 3; LastUsed = [DateTime]::Now.AddDays(-2) }
            )
            
            foreach ($cmdData in $commands) {
                $cmdData.CommandText = "Test-Command"
                $command = [Command]::new($cmdData)
                $created = $script:service.Create($command)
                
                # Manually set usage data (since we can't easily mock time in constructor)
                $created.UseCount = $cmdData.UseCount
                $created.LastUsed = $cmdData.LastUsed
                $script:service.Update($created) | Out-Null
            }
        }
        
        It "Should sort commands by title ascending" {
            $allCommands = $script:service.GetAll()
            $sorted = $script:service.SortCommands($allCommands, "title", $false)
            
            $sorted[0].Title | Should -Be "AA First"
            $sorted[1].Title | Should -Be "MM Middle"
            $sorted[2].Title | Should -Be "ZZ Last"
        }
        
        It "Should sort commands by title descending" {
            $allCommands = $script:service.GetAll()
            $sorted = $script:service.SortCommands($allCommands, "title", $true)
            
            $sorted[0].Title | Should -Be "ZZ Last"
            $sorted[1].Title | Should -Be "MM Middle"
            $sorted[2].Title | Should -Be "AA First"
        }
        
        It "Should sort commands by use count" {
            $allCommands = $script:service.GetAll()
            $sorted = $script:service.SortCommands($allCommands, "usecount", $true)
            
            $sorted[0].UseCount | Should -BeGreaterOrEqual $sorted[1].UseCount
            $sorted[1].UseCount | Should -BeGreaterOrEqual $sorted[2].UseCount
        }
        
        It "Should paginate commands correctly" {
            # Add more commands to test pagination
            for ($i = 4; $i -le 10; $i++) {
                $command = [Command]::new(@{
                    Title = "Extra Command $i"
                    CommandText = "Test-Extra$i"
                })
                $script:service.Create($command) | Out-Null
            }
            
            $allCommands = $script:service.GetAll()
            $page1 = $script:service.PaginateCommands($allCommands, 1, 5)
            $page2 = $script:service.PaginateCommands($allCommands, 2, 5)
            
            $page1.Count | Should -Be 5
            $page2.Count | Should -Be 5
            
            # Ensure no overlap
            $page1Ids = $page1 | Select-Object -ExpandProperty Id
            $page2Ids = $page2 | Select-Object -ExpandProperty Id
            
            foreach ($id in $page1Ids) {
                $page2Ids | Should -Not -Contain $id
            }
        }
        
        It "Should handle pagination beyond available data" {
            $allCommands = $script:service.GetAll()
            $emptyPage = $script:service.PaginateCommands($allCommands, 10, 5)
            
            $emptyPage.Count | Should -Be 0
        }
    }
    
    Context "Cache Management" {
        It "Should clear caches correctly" {
            # Populate caches
            $script:service.Search("test") | Out-Null
            
            $script:service.SearchCache.Count | Should -BeGreaterThan 0
            
            $script:service.ClearCommandCaches()
            
            $script:service.SearchCache.Count | Should -Be 0
            $script:service.GroupCache.Count | Should -Be 0
        }
        
        It "Should refresh caches and pre-populate common searches" {
            # Create commands that would match common searches
            $command = [Command]::new(@{
                Title = "Git Test Command"
                CommandText = "git status"
                Tags = @("git")
            })
            $script:service.Create($command) | Out-Null
            
            $script:service.RefreshCaches()
            
            # Check that common searches were pre-populated
            $script:service.SearchCache.ContainsKey("git") | Should -Be $true
        }
    }
    
    Context "Validation and Error Handling" {
        It "Should validate commands correctly" {
            $validCommand = [Command]::new(@{
                Title = "Valid Command"
                CommandText = "Get-Process"
            })
            
            $script:service.ValidateCommand($validCommand) | Should -Be $true
        }
        
        It "Should reject invalid commands" {
            $invalidCommand = [Command]::new(@{
                Title = "Invalid Command"
                CommandText = ""  # Empty command text
            })
            
            $script:service.ValidateCommand($invalidCommand) | Should -Be $false
        }
        
        It "Should throw error when creating invalid command" {
            $invalidCommand = [Command]::new(@{
                Title = ""  # Invalid: empty title and will fail IsValid()
                CommandText = ""  # Invalid: empty command text
            })
            
            {
                $script:service.Create($invalidCommand)
            } | Should -Throw "Cannot create invalid command entity"
        }
        
        It "Should handle non-existent command IDs gracefully" {
            $result = $script:service.GetById("non-existent-id")
            $result | Should -BeNull
        }
    }
}