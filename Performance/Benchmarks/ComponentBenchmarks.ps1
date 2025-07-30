# ComponentBenchmarks.ps1 - Specific benchmarks for PRAXIS UI components
# Measures render performance, invalidation patterns, and memory usage

# Load the benchmark framework
. "$PSScriptRoot/BenchmarkFramework.ps1"

class ComponentBenchmarks {
    [BenchmarkFramework]$Framework
    [hashtable]$ComponentResults
    [ServiceContainer]$Services
    
    ComponentBenchmarks() {
        $this.Framework = [BenchmarkFramework]::new("PRAXIS Component Benchmarks")
        $this.ComponentResults = @{}
        
        # Initialize minimal services for testing
        $this.InitializeServices()
    }
    
    [void] InitializeServices() {
        # Create service container
        $this.Services = [ServiceContainer]::new()
        
        # Mock logger
        $mockLogger = [PSCustomObject]@{
            Debug = { param($msg) }
            Info = { param($msg) }
            Error = { param($msg) }
            LogException = { param($ex, $msg) }
        }
        $this.Services.Register("Logger", $mockLogger)
        
        # Mock theme manager
        $mockTheme = [PSCustomObject]@{
            GetColor = { param($key) return "`e[37m" }
            GetBgColor = { param($key) return "`e[40m" }
            Subscribe = { param($callback) }
        }
        $this.Services.Register("ThemeManager", $mockTheme)
        
        # Mock focus manager
        $mockFocus = [PSCustomObject]@{
            RegisterFocusable = { param($element) }
            SetFocus = { param($element) return $true }
            GetFocused = { return $null }
        }
        $this.Services.Register("FocusManager", $mockFocus)
    }
    
    # Benchmark MinimalDataGrid with varying data sizes
    [void] BenchmarkDataGrid() {
        Write-Host "`nBenchmarking MinimalDataGrid..." -ForegroundColor Cyan
        
        $dataSizes = @(10, 50, 100, 500, 1000, 5000)
        $results = @{}
        
        foreach ($size in $dataSizes) {
            Write-Host "  Testing with $size items..." -ForegroundColor Gray
            
            # Create test data
            $testData = 1..$size | ForEach-Object {
                [PSCustomObject]@{
                    Id = $_
                    Name = "Item $_"
                    Status = if ($_ % 3 -eq 0) { "Active" } else { "Inactive" }
                    Value = Get-Random -Maximum 1000
                    Description = "Description for item $_ with some longer text"
                }
            }
            
            # Create and configure grid
            $grid = [MinimalDataGrid]::new()
            $grid.Initialize($this.Services)
            $grid.SetBounds(0, 0, 120, 30)
            
            # Add columns
            $grid.AddColumn("Id", { param($item) $item.Id }, 10)
            $grid.AddColumn("Name", { param($item) $item.Name }, 30)
            $grid.AddColumn("Status", { param($item) $item.Status }, 15)
            $grid.AddColumn("Value", { param($item) $item.Value }, 10)
            $grid.AddColumn("Description", { param($item) $item.Description }, 40)
            
            # Set items
            $grid.SetItems($testData)
            
            # Benchmark initial render
            $initialRender = $this.Framework.MeasureRenderCycles($grid, "DataGrid_${size}_Initial")
            $results["Initial_$size"] = $initialRender
            
            # Benchmark selection changes
            $selectionBench = $this.BenchmarkDataGridSelection($grid, $size)
            $results["Selection_$size"] = $selectionBench
            
            # Benchmark scrolling
            if ($size -gt 30) {
                $scrollBench = $this.BenchmarkDataGridScrolling($grid, $size)
                $results["Scroll_$size"] = $scrollBench
            }
            
            # Benchmark item updates
            $updateBench = $this.BenchmarkDataGridUpdates($grid, $testData)
            $results["Update_$size"] = $updateBench
        }
        
        $this.ComponentResults["MinimalDataGrid"] = $results
    }
    
    # Benchmark selection changes in data grid
    [RenderBenchmark] BenchmarkDataGridSelection([MinimalDataGrid]$grid, [int]$itemCount) {
        $benchmark = [RenderBenchmark]::new("DataGrid_Selection_$itemCount", $grid)
        $times = [System.Collections.Generic.List[double]]::new()
        
        # Test selection changes
        $positions = @(0, [int]($itemCount/4), [int]($itemCount/2), [int](3*$itemCount/4), $itemCount-1)
        
        foreach ($run in 1..20) {
            foreach ($pos in $positions) {
                $grid.SelectedIndex = $pos
                $grid._cacheInvalid = $true
                
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                $_ = $grid.Render()
                $timer.Stop()
                
                $times.Add($timer.Elapsed.TotalMilliseconds)
            }
        }
        
        $benchmark.CalculateStats($times)
        return $benchmark
    }
    
    # Benchmark scrolling performance
    [RenderBenchmark] BenchmarkDataGridScrolling([MinimalDataGrid]$grid, [int]$itemCount) {
        $benchmark = [RenderBenchmark]::new("DataGrid_Scrolling_$itemCount", $grid)
        $times = [System.Collections.Generic.List[double]]::new()
        
        # Simulate scrolling through the list
        $scrollSteps = [Math]::Min(100, $itemCount / 10)
        $stepSize = [Math]::Max(1, [int]($itemCount / $scrollSteps))
        
        for ($i = 0; $i -lt $itemCount - $grid._viewportRows; $i += $stepSize) {
            $grid._scrollOffset = $i
            $grid._cacheInvalid = $true
            $grid._rowsInvalid = $true
            
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $_ = $grid.Render()
            $timer.Stop()
            
            $times.Add($timer.Elapsed.TotalMilliseconds)
        }
        
        $benchmark.CalculateStats($times)
        return $benchmark
    }
    
    # Benchmark item updates
    [RenderBenchmark] BenchmarkDataGridUpdates([MinimalDataGrid]$grid, [array]$testData) {
        $benchmark = [RenderBenchmark]::new("DataGrid_Updates_$($testData.Count)", $grid)
        $times = [System.Collections.Generic.List[double]]::new()
        
        # Test various update scenarios
        for ($i = 0; $i -lt 50; $i++) {
            # Modify random item
            $index = Get-Random -Maximum $testData.Count
            $testData[$index].Status = if ($testData[$index].Status -eq "Active") { "Inactive" } else { "Active" }
            $testData[$index].Value = Get-Random -Maximum 2000
            
            # Update grid
            $grid.SetItems($testData)
            
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $_ = $grid.Render()
            $timer.Stop()
            
            $times.Add($timer.Elapsed.TotalMilliseconds)
        }
        
        $benchmark.CalculateStats($times)
        return $benchmark
    }
    
    # Benchmark TabContainer
    [void] BenchmarkTabContainer() {
        Write-Host "`nBenchmarking TabContainer..." -ForegroundColor Cyan
        
        $tabCounts = @(3, 5, 10, 20)
        $results = @{}
        
        foreach ($count in $tabCounts) {
            Write-Host "  Testing with $count tabs..." -ForegroundColor Gray
            
            # Create tab container
            $tabContainer = [TabContainer]::new()
            $tabContainer.Initialize($this.Services)
            $tabContainer.SetBounds(0, 0, 120, 30)
            
            # Add tabs
            for ($i = 1; $i -le $count; $i++) {
                $content = [MinimalTextBox]::new()
                $content.Text = "Content for tab $i`nThis is a test of tab rendering performance.`nLine 3`nLine 4"
                $tabContainer.AddTab("Tab $i", $content)
            }
            
            # Benchmark initial render
            $initialRender = $this.Framework.MeasureRenderCycles($tabContainer, "TabContainer_${count}_Initial")
            $results["Initial_$count"] = $initialRender
            
            # Benchmark tab switching
            $switchBench = $this.BenchmarkTabSwitching($tabContainer, $count)
            $results["Switching_$count"] = $switchBench
        }
        
        $this.ComponentResults["TabContainer"] = $results
    }
    
    # Benchmark tab switching
    [RenderBenchmark] BenchmarkTabSwitching([TabContainer]$tabs, [int]$tabCount) {
        $benchmark = [RenderBenchmark]::new("TabContainer_Switching_$tabCount", $tabs)
        $times = [System.Collections.Generic.List[double]]::new()
        
        # Switch through all tabs multiple times
        for ($run in 1..10) {
            for ($i = 0; $i -lt $tabCount; $i++) {
                $tabs.ActiveTabIndex = $i
                $tabs._cacheInvalid = $true
                
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                $_ = $tabs.Render()
                $timer.Stop()
                
                $times.Add($timer.Elapsed.TotalMilliseconds)
            }
        }
        
        $benchmark.CalculateStats($times)
        return $benchmark
    }
    
    # Benchmark CommandPalette
    [void] BenchmarkCommandPalette() {
        Write-Host "`nBenchmarking CommandPalette..." -ForegroundColor Cyan
        
        $commandCounts = @(10, 50, 100, 500)
        $results = @{}
        
        foreach ($count in $commandCounts) {
            Write-Host "  Testing with $count commands..." -ForegroundColor Gray
            
            # Create command palette
            $palette = [CommandPalette]::new()
            $palette.Initialize($this.Services)
            $palette.SetBounds(20, 5, 80, 20)
            
            # Add test commands
            $commands = 1..$count | ForEach-Object {
                @{
                    Id = "cmd_$_"
                    Name = "Command $_"
                    Description = "Description for command $_ with some details"
                    Category = "Category $($_ % 5)"
                    Action = { Write-Host "Executing command $_" }
                }
            }
            $palette.SetCommands($commands)
            
            # Benchmark initial render
            $initialRender = $this.Framework.MeasureRenderCycles($palette, "CommandPalette_${count}_Initial")
            $results["Initial_$count"] = $initialRender
            
            # Benchmark search/filtering
            $searchBench = $this.BenchmarkCommandSearch($palette, $count)
            $results["Search_$count"] = $searchBench
        }
        
        $this.ComponentResults["CommandPalette"] = $results
    }
    
    # Benchmark command search/filtering
    [RenderBenchmark] BenchmarkCommandSearch([CommandPalette]$palette, [int]$commandCount) {
        $benchmark = [RenderBenchmark]::new("CommandPalette_Search_$commandCount", $palette)
        $times = [System.Collections.Generic.List[double]]::new()
        
        $searchTerms = @("", "c", "co", "com", "comm", "command", "1", "10", "cat", "category")
        
        foreach ($run in 1..5) {
            foreach ($term in $searchTerms) {
                $palette._searchText = $term
                $palette.FilterCommands()
                $palette._cacheInvalid = $true
                
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                $_ = $palette.Render()
                $timer.Stop()
                
                $times.Add($timer.Elapsed.TotalMilliseconds)
            }
        }
        
        $benchmark.CalculateStats($times)
        return $benchmark
    }
    
    # Benchmark complex nested layouts
    [void] BenchmarkNestedLayouts() {
        Write-Host "`nBenchmarking Nested Layouts..." -ForegroundColor Cyan
        
        $results = @{}
        
        # Create a complex nested layout
        $root = [Container]::new()
        $root.Initialize($this.Services)
        $root.SetBounds(0, 0, 120, 40)
        
        # Horizontal split with vertical splits inside
        $hSplit = [HorizontalSplit]::new()
        $hSplit.SplitPosition = 60
        
        # Left side - vertical split
        $leftVSplit = [VerticalSplit]::new()
        $leftVSplit.SplitPosition = 20
        
        # Add content to left vertical split
        $topList = [MinimalListBox]::new()
        $topList.Items.AddRange((1..50 | ForEach-Object { "Item $_" }))
        $leftVSplit.TopPanel = $topList
        
        $bottomGrid = [MinimalDataGrid]::new()
        $bottomGrid.Initialize($this.Services)
        $testData = 1..30 | ForEach-Object { [PSCustomObject]@{ Id = $_; Name = "Row $_" } }
        $bottomGrid.SetItems($testData)
        $leftVSplit.BottomPanel = $bottomGrid
        
        # Right side - another vertical split
        $rightVSplit = [VerticalSplit]::new()
        $rightVSplit.SplitPosition = 25
        
        $topText = [MinimalTextBox]::new()
        $topText.Text = "Sample text content`nLine 2`nLine 3"
        $rightVSplit.TopPanel = $topText
        
        $bottomList = [MinimalListBox]::new()
        $bottomList.Items.AddRange((1..20 | ForEach-Object { "Option $_" }))
        $rightVSplit.BottomPanel = $bottomList
        
        # Assemble the layout
        $hSplit.LeftPanel = $leftVSplit
        $hSplit.RightPanel = $rightVSplit
        $root.AddChild($hSplit)
        
        # Initialize all components
        $root.Initialize($this.Services)
        $root.SetBounds(0, 0, 120, 40)
        
        # Benchmark the complex layout
        $layoutBench = $this.Framework.MeasureRenderCycles($root, "NestedLayout_Complex")
        $results["Complex"] = $layoutBench
        
        # Benchmark resize operations
        $resizeBench = $this.BenchmarkLayoutResize($root)
        $results["Resize"] = $resizeBench
        
        $this.ComponentResults["NestedLayouts"] = $results
    }
    
    # Benchmark layout resize
    [RenderBenchmark] BenchmarkLayoutResize([Container]$layout) {
        $benchmark = [RenderBenchmark]::new("Layout_Resize", $layout)
        $times = [System.Collections.Generic.List[double]]::new()
        
        $widths = @(80, 100, 120, 140, 120, 100, 80)
        $heights = @(30, 35, 40, 45, 40, 35, 30)
        
        for ($run in 1..5) {
            for ($i = 0; $i -lt $widths.Count; $i++) {
                $layout.SetBounds(0, 0, $widths[$i], $heights[$i])
                
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                $_ = $layout.Render()
                $timer.Stop()
                
                $times.Add($timer.Elapsed.TotalMilliseconds)
            }
        }
        
        $benchmark.CalculateStats($times)
        return $benchmark
    }
    
    # Run all benchmarks
    [void] RunAllBenchmarks() {
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host "PRAXIS UI COMPONENT PERFORMANCE BENCHMARKS" -ForegroundColor Yellow
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host ""
        
        $startTime = Get-Date
        
        # Run individual benchmarks
        $this.BenchmarkDataGrid()
        $this.BenchmarkTabContainer()
        $this.BenchmarkCommandPalette()
        $this.BenchmarkNestedLayouts()
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "`nBenchmarks completed in $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Green
        
        # Generate report
        $this.GenerateReport()
    }
    
    # Generate comprehensive report
    [void] GenerateReport() {
        $reportPath = Join-Path $PSScriptRoot "BenchmarkReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("=" * 80)
        $sb.AppendLine("PRAXIS UI COMPONENT PERFORMANCE BENCHMARK REPORT")
        $sb.AppendLine("=" * 80)
        $sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $sb.AppendLine("System: $([Environment]::MachineName)")
        $sb.AppendLine("PowerShell: $($PSVersionTable.PSVersion)")
        $sb.AppendLine()
        
        # Summary by component
        foreach ($component in $this.ComponentResults.Keys | Sort-Object) {
            $sb.AppendLine()
            $sb.AppendLine("## $component")
            $sb.AppendLine("-" * 50)
            
            $results = $this.ComponentResults[$component]
            foreach ($test in $results.Keys | Sort-Object) {
                $result = $results[$test]
                $sb.AppendLine()
                $sb.AppendLine($result.ToString())
            }
        }
        
        # Performance insights
        $sb.AppendLine()
        $sb.AppendLine("=" * 80)
        $sb.AppendLine("PERFORMANCE INSIGHTS")
        $sb.AppendLine("=" * 80)
        $this.GenerateInsights($sb)
        
        # Save report
        $sb.ToString() | Set-Content -Path $reportPath
        Write-Host "`nReport saved to: $reportPath" -ForegroundColor Cyan
        
        # Also display summary to console
        $this.DisplaySummary()
    }
    
    # Generate performance insights
    [void] GenerateInsights([System.Text.StringBuilder]$sb) {
        # Analyze DataGrid scaling
        if ($this.ComponentResults.ContainsKey("MinimalDataGrid")) {
            $dgResults = $this.ComponentResults["MinimalDataGrid"]
            $sb.AppendLine()
            $sb.AppendLine("DataGrid Performance Scaling:")
            
            $sizes = @(10, 50, 100, 500, 1000, 5000)
            foreach ($size in $sizes) {
                if ($dgResults.ContainsKey("Initial_$size")) {
                    $result = $dgResults["Initial_$size"]
                    $sb.AppendLine("  $size items: $($result.AvgTime.ToString('F2'))ms avg render time")
                }
            }
            
            # Calculate scaling factor
            if ($dgResults.ContainsKey("Initial_10") -and $dgResults.ContainsKey("Initial_1000")) {
                $small = $dgResults["Initial_10"].AvgTime
                $large = $dgResults["Initial_1000"].AvgTime
                $scalingFactor = $large / $small
                $sb.AppendLine("  Scaling factor (10→1000): ${scalingFactor}x")
                
                if ($scalingFactor -lt 10) {
                    $sb.AppendLine("  ✓ Good scaling performance")
                } elseif ($scalingFactor -lt 50) {
                    $sb.AppendLine("  ⚠ Moderate scaling issues")
                } else {
                    $sb.AppendLine("  ✗ Poor scaling performance")
                }
            }
        }
        
        # Analyze caching effectiveness
        $sb.AppendLine()
        $sb.AppendLine("Caching Effectiveness:")
        foreach ($component in $this.ComponentResults.Keys) {
            $results = $this.ComponentResults[$component]
            foreach ($key in $results.Keys) {
                $result = $results[$key]
                if ($result -is [RenderBenchmark] -and $result.CacheHitRate -gt 0) {
                    $sb.AppendLine("  $component.$key: $([Math]::Round($result.CacheHitRate * 100, 1))% cache hit rate")
                }
            }
        }
    }
    
    # Display summary to console
    [void] DisplaySummary() {
        Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
        Write-Host "PERFORMANCE SUMMARY" -ForegroundColor Cyan
        Write-Host "=" * 80 -ForegroundColor Cyan
        
        # Find fastest and slowest components
        $allResults = @()
        foreach ($component in $this.ComponentResults.Keys) {
            $results = $this.ComponentResults[$component]
            foreach ($key in $results.Keys) {
                $result = $results[$key]
                if ($result -is [RenderBenchmark]) {
                    $allResults += [PSCustomObject]@{
                        Component = $component
                        Test = $key
                        AvgTime = $result.AvgTime
                        P95Time = $result.P95Time
                    }
                }
            }
        }
        
        # Top 5 fastest
        Write-Host "`nFastest Components (by average render time):" -ForegroundColor Green
        $allResults | Sort-Object AvgTime | Select-Object -First 5 | ForEach-Object {
            Write-Host ("  {0,-30} {1,8:F2}ms" -f "$($_.Component).$($_.Test)", $_.AvgTime)
        }
        
        # Top 5 slowest
        Write-Host "`nSlowest Components (by average render time):" -ForegroundColor Red
        $allResults | Sort-Object AvgTime -Descending | Select-Object -First 5 | ForEach-Object {
            Write-Host ("  {0,-30} {1,8:F2}ms" -f "$($_.Component).$($_.Test)", $_.AvgTime)
        }
        
        # Memory usage summary
        Write-Host "`nMemory Usage Summary:" -ForegroundColor Yellow
        $memoryResults = @()
        foreach ($component in $this.ComponentResults.Keys) {
            $results = $this.ComponentResults[$component]
            foreach ($key in $results.Keys) {
                $result = $results[$key]
                if ($result -is [RenderBenchmark] -and $result.MemoryDelta -ne 0) {
                    $memoryResults += [PSCustomObject]@{
                        Component = "$component.$key"
                        MemoryMB = [Math]::Round($result.MemoryDelta / 1MB, 2)
                    }
                }
            }
        }
        
        if ($memoryResults.Count -gt 0) {
            $memoryResults | Sort-Object MemoryMB -Descending | Select-Object -First 5 | ForEach-Object {
                Write-Host ("  {0,-40} {1,8:F2}MB" -f $_.Component, $_.MemoryMB)
            }
        }
    }
}

# Export the class
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *