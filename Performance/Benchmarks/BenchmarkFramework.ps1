# BenchmarkFramework.ps1 - Core UI performance benchmarking framework
# Designed for precise measurement of render cycles and component performance

class BenchmarkFramework {
    # Core properties
    [string]$Name
    [hashtable]$Results
    [System.Diagnostics.Stopwatch]$Timer
    [System.Collections.Generic.List[BenchmarkRun]]$Runs
    
    # Configuration
    [int]$WarmupRuns = 5
    [int]$MeasurementRuns = 100
    [bool]$DetailedMetrics = $true
    [bool]$CollectMemory = $true
    [bool]$ProfileRenderCycles = $true
    
    # Performance counters
    hidden [hashtable]$_counters
    hidden [hashtable]$_renderMetrics
    hidden [hashtable]$_memoryBaselines
    
    BenchmarkFramework([string]$name) {
        $this.Name = $name
        $this.Results = @{}
        $this.Timer = [System.Diagnostics.Stopwatch]::new()
        $this.Runs = [System.Collections.Generic.List[BenchmarkRun]]::new()
        $this._counters = @{}
        $this._renderMetrics = @{}
        $this._memoryBaselines = @{}
    }
    
    # Start a benchmark section
    [BenchmarkSection] StartSection([string]$name) {
        $section = [BenchmarkSection]::new($name, $this)
        return $section
    }
    
    # Measure render cycles for a UI component
    [RenderBenchmark] MeasureRenderCycles([UIElement]$component, [string]$testName) {
        $benchmark = [RenderBenchmark]::new($testName, $component)
        
        # Collect baseline memory
        if ($this.CollectMemory) {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $benchmark.BaselineMemory = [GC]::GetTotalMemory($false)
        }
        
        # Warmup runs
        for ($i = 0; $i -lt $this.WarmupRuns; $i++) {
            $component.Invalidate()
            $_ = $component.Render()
        }
        
        # Measurement runs
        $times = [System.Collections.Generic.List[double]]::new()
        $cacheHits = 0
        $cacheInvalidations = 0
        
        for ($i = 0; $i -lt $this.MeasurementRuns; $i++) {
            # Force invalidation for consistent measurements
            $component._cacheInvalid = $true
            
            # Measure render time
            $this.Timer.Restart()
            $rendered = $component.Render()
            $this.Timer.Stop()
            
            $times.Add($this.Timer.Elapsed.TotalMilliseconds)
            
            # Track cache behavior
            if (-not $component._cacheInvalid) {
                $cacheHits++
            }
            
            # Simulate changes that would invalidate cache
            if ($i % 10 -eq 0) {
                $component.Invalidate()
                $cacheInvalidations++
            }
        }
        
        # Calculate statistics
        $benchmark.CalculateStats($times)
        $benchmark.CacheHitRate = $cacheHits / $this.MeasurementRuns
        $benchmark.InvalidationCount = $cacheInvalidations
        
        # Memory after test
        if ($this.CollectMemory) {
            [GC]::Collect()
            $benchmark.FinalMemory = [GC]::GetTotalMemory($false)
            $benchmark.MemoryDelta = $benchmark.FinalMemory - $benchmark.BaselineMemory
        }
        
        # Profile render characteristics
        if ($this.ProfileRenderCycles) {
            $benchmark.ProfileRenderCharacteristics($component)
        }
        
        return $benchmark
    }
    
    # Benchmark input handling performance
    [InputBenchmark] MeasureInputHandling([UIElement]$component, [System.ConsoleKeyInfo[]]$keys) {
        $benchmark = [InputBenchmark]::new("Input Handling", $component)
        
        # Measure each key handling
        $times = [System.Collections.Generic.List[double]]::new()
        $handled = 0
        
        foreach ($key in $keys) {
            $this.Timer.Restart()
            $result = $component.HandleInput($key)
            $this.Timer.Stop()
            
            $times.Add($this.Timer.Elapsed.TotalMilliseconds)
            if ($result) { $handled++ }
        }
        
        $benchmark.CalculateStats($times)
        $benchmark.HandledRate = $handled / $keys.Count
        $benchmark.TotalKeys = $keys.Count
        
        return $benchmark
    }
    
    # Compare two implementations
    [ComparisonResult] Compare([scriptblock]$oldImplementation, [scriptblock]$newImplementation) {
        $comparison = [ComparisonResult]::new()
        
        # Benchmark old implementation
        Write-Host "Benchmarking old implementation..." -ForegroundColor Yellow
        $oldResults = $this.RunBenchmark($oldImplementation, "Old")
        
        # Benchmark new implementation
        Write-Host "Benchmarking new implementation..." -ForegroundColor Yellow
        $newResults = $this.RunBenchmark($newImplementation, "New")
        
        # Calculate improvements
        $comparison.OldResults = $oldResults
        $comparison.NewResults = $newResults
        $comparison.CalculateImprovements()
        
        return $comparison
    }
    
    # Run a benchmark with detailed profiling
    [BenchmarkResult] RunBenchmark([scriptblock]$code, [string]$label) {
        $result = [BenchmarkResult]::new($label)
        
        # Collect initial state
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        $result.InitialMemory = [GC]::GetTotalMemory($false)
        
        # Warmup
        for ($i = 0; $i -lt $this.WarmupRuns; $i++) {
            & $code
        }
        
        # Measurement runs
        $times = [System.Collections.Generic.List[double]]::new()
        
        for ($i = 0; $i -lt $this.MeasurementRuns; $i++) {
            $this.Timer.Restart()
            & $code
            $this.Timer.Stop()
            $times.Add($this.Timer.Elapsed.TotalMilliseconds)
        }
        
        # Final memory state
        [GC]::Collect()
        $result.FinalMemory = [GC]::GetTotalMemory($false)
        
        # Calculate statistics
        $result.CalculateStatistics($times)
        
        return $result
    }
    
    # Generate detailed report
    [string] GenerateReport() {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.AppendLine("=" * 80)
        $sb.AppendLine("PERFORMANCE BENCHMARK REPORT: $($this.Name)")
        $sb.AppendLine("=" * 80)
        $sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $sb.AppendLine()
        
        # Summary of all benchmarks
        foreach ($key in $this.Results.Keys) {
            $result = $this.Results[$key]
            $sb.AppendLine($result.ToString())
            $sb.AppendLine()
        }
        
        return $sb.ToString()
    }
    
    # Export results to JSON
    [void] ExportResults([string]$path) {
        $exportData = @{
            Name = $this.Name
            Timestamp = Get-Date -Format "o"
            Results = $this.Results
            Configuration = @{
                WarmupRuns = $this.WarmupRuns
                MeasurementRuns = $this.MeasurementRuns
                DetailedMetrics = $this.DetailedMetrics
                CollectMemory = $this.CollectMemory
            }
        }
        
        $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $path
    }
}

# Benchmark section for grouping related measurements
class BenchmarkSection : System.IDisposable {
    [string]$Name
    [BenchmarkFramework]$Framework
    [System.Diagnostics.Stopwatch]$Timer
    [long]$StartMemory
    
    BenchmarkSection([string]$name, [BenchmarkFramework]$framework) {
        $this.Name = $name
        $this.Framework = $framework
        $this.Timer = [System.Diagnostics.Stopwatch]::StartNew()
        
        if ($framework.CollectMemory) {
            [GC]::Collect()
            $this.StartMemory = [GC]::GetTotalMemory($false)
        }
    }
    
    [void] Dispose() {
        $this.Timer.Stop()
        
        $result = @{
            Duration = $this.Timer.Elapsed.TotalMilliseconds
            Name = $this.Name
        }
        
        if ($this.Framework.CollectMemory) {
            [GC]::Collect()
            $endMemory = [GC]::GetTotalMemory($false)
            $result.MemoryDelta = $endMemory - $this.StartMemory
        }
        
        $this.Framework.Results[$this.Name] = $result
    }
}

# Render-specific benchmark results
class RenderBenchmark {
    [string]$Name
    [UIElement]$Component
    [double]$MinTime
    [double]$MaxTime
    [double]$AvgTime
    [double]$MedianTime
    [double]$StdDev
    [double]$P95Time
    [double]$P99Time
    [double]$CacheHitRate
    [int]$InvalidationCount
    [long]$BaselineMemory
    [long]$FinalMemory
    [long]$MemoryDelta
    [hashtable]$RenderProfile
    
    RenderBenchmark([string]$name, [UIElement]$component) {
        $this.Name = $name
        $this.Component = $component
        $this.RenderProfile = @{}
    }
    
    [void] CalculateStats([System.Collections.Generic.List[double]]$times) {
        $sorted = $times | Sort-Object
        $this.MinTime = $sorted[0]
        $this.MaxTime = $sorted[-1]
        $this.AvgTime = ($times | Measure-Object -Average).Average
        $this.MedianTime = $sorted[[int]($sorted.Count / 2)]
        
        # Standard deviation
        $variance = 0
        foreach ($time in $times) {
            $variance += [Math]::Pow($time - $this.AvgTime, 2)
        }
        $this.StdDev = [Math]::Sqrt($variance / $times.Count)
        
        # Percentiles
        $this.P95Time = $sorted[[int]($sorted.Count * 0.95)]
        $this.P99Time = $sorted[[int]($sorted.Count * 0.99)]
    }
    
    [void] ProfileRenderCharacteristics([UIElement]$component) {
        # Measure different aspects of rendering
        
        # String allocation count
        $preStrings = [GC]::CollectionCount(0)
        $_ = $component.Render()
        $postStrings = [GC]::CollectionCount(0)
        $this.RenderProfile["StringAllocations"] = $postStrings - $preStrings
        
        # Render output size
        $output = $component.Render()
        $this.RenderProfile["OutputSize"] = $output.Length
        $this.RenderProfile["OutputLines"] = ($output -split "`n").Count
        
        # ANSI sequence count
        $ansiPattern = '\x1b\[[0-9;]*[mGKHfl]'
        $matches = [regex]::Matches($output, $ansiPattern)
        $this.RenderProfile["AnsiSequences"] = $matches.Count
        
        # Component complexity
        $this.RenderProfile["ChildCount"] = $component.Children.Count
        $this.RenderProfile["Width"] = $component.Width
        $this.RenderProfile["Height"] = $component.Height
        $this.RenderProfile["Area"] = $component.Width * $component.Height
    }
    
    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("Render Benchmark: $($this.Name)")
        $sb.AppendLine("  Component: $($this.Component.GetType().Name)")
        $sb.AppendLine("  Times (ms): Min=$($this.MinTime.ToString('F3')), Avg=$($this.AvgTime.ToString('F3')), Max=$($this.MaxTime.ToString('F3'))")
        $sb.AppendLine("  Percentiles: P95=$($this.P95Time.ToString('F3'))ms, P99=$($this.P99Time.ToString('F3'))ms")
        $sb.AppendLine("  Cache Hit Rate: $([Math]::Round($this.CacheHitRate * 100, 1))%")
        
        if ($this.MemoryDelta -ne 0) {
            $mb = $this.MemoryDelta / 1MB
            $sb.AppendLine("  Memory Delta: $($mb.ToString('F2')) MB")
        }
        
        if ($this.RenderProfile.Count -gt 0) {
            $sb.AppendLine("  Render Profile:")
            foreach ($key in $this.RenderProfile.Keys | Sort-Object) {
                $sb.AppendLine("    $key`: $($this.RenderProfile[$key])")
            }
        }
        
        return $sb.ToString()
    }
}

# Input handling benchmark results
class InputBenchmark {
    [string]$Name
    [UIElement]$Component
    [double]$MinTime
    [double]$MaxTime
    [double]$AvgTime
    [double]$MedianTime
    [double]$StdDev
    [double]$HandledRate
    [int]$TotalKeys
    
    InputBenchmark([string]$name, [UIElement]$component) {
        $this.Name = $name
        $this.Component = $component
    }
    
    [void] CalculateStats([System.Collections.Generic.List[double]]$times) {
        $sorted = $times | Sort-Object
        $this.MinTime = $sorted[0]
        $this.MaxTime = $sorted[-1]
        $this.AvgTime = ($times | Measure-Object -Average).Average
        $this.MedianTime = $sorted[[int]($sorted.Count / 2)]
        
        # Standard deviation
        $variance = 0
        foreach ($time in $times) {
            $variance += [Math]::Pow($time - $this.AvgTime, 2)
        }
        $this.StdDev = [Math]::Sqrt($variance / $times.Count)
    }
    
    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("Input Benchmark: $($this.Name)")
        $sb.AppendLine("  Component: $($this.Component.GetType().Name)")
        $sb.AppendLine("  Keys Tested: $($this.TotalKeys)")
        $sb.AppendLine("  Handled Rate: $([Math]::Round($this.HandledRate * 100, 1))%")
        $sb.AppendLine("  Times (ms): Min=$($this.MinTime.ToString('F3')), Avg=$($this.AvgTime.ToString('F3')), Max=$($this.MaxTime.ToString('F3'))")
        return $sb.ToString()
    }
}

# General benchmark result
class BenchmarkResult {
    [string]$Label
    [double]$MinTime
    [double]$MaxTime
    [double]$AvgTime
    [double]$MedianTime
    [double]$StdDev
    [double]$P95Time
    [double]$P99Time
    [long]$InitialMemory
    [long]$FinalMemory
    [long]$MemoryDelta
    [int]$RunCount
    
    BenchmarkResult([string]$label) {
        $this.Label = $label
    }
    
    [void] CalculateStatistics([System.Collections.Generic.List[double]]$times) {
        $this.RunCount = $times.Count
        $sorted = $times | Sort-Object
        $this.MinTime = $sorted[0]
        $this.MaxTime = $sorted[-1]
        $this.AvgTime = ($times | Measure-Object -Average).Average
        $this.MedianTime = $sorted[[int]($sorted.Count / 2)]
        
        # Standard deviation
        $variance = 0
        foreach ($time in $times) {
            $variance += [Math]::Pow($time - $this.AvgTime, 2)
        }
        $this.StdDev = [Math]::Sqrt($variance / $times.Count)
        
        # Percentiles
        $this.P95Time = $sorted[[int]($sorted.Count * 0.95)]
        $this.P99Time = $sorted[[int]($sorted.Count * 0.99)]
        
        $this.MemoryDelta = $this.FinalMemory - $this.InitialMemory
    }
    
    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("Benchmark: $($this.Label)")
        $sb.AppendLine("  Runs: $($this.RunCount)")
        $sb.AppendLine("  Times (ms): Min=$($this.MinTime.ToString('F3')), Avg=$($this.AvgTime.ToString('F3')), Max=$($this.MaxTime.ToString('F3'))")
        $sb.AppendLine("  StdDev: $($this.StdDev.ToString('F3'))ms")
        $sb.AppendLine("  Percentiles: P95=$($this.P95Time.ToString('F3'))ms, P99=$($this.P99Time.ToString('F3'))ms")
        
        if ($this.MemoryDelta -ne 0) {
            $mb = $this.MemoryDelta / 1MB
            $sb.AppendLine("  Memory Delta: $($mb.ToString('F2')) MB")
        }
        
        return $sb.ToString()
    }
}

# Comparison result between two implementations
class ComparisonResult {
    [BenchmarkResult]$OldResults
    [BenchmarkResult]$NewResults
    [double]$SpeedImprovement
    [double]$MemoryImprovement
    [hashtable]$Improvements
    
    ComparisonResult() {
        $this.Improvements = @{}
    }
    
    [void] CalculateImprovements() {
        # Speed improvement (positive = faster)
        $this.SpeedImprovement = (($this.OldResults.AvgTime - $this.NewResults.AvgTime) / $this.OldResults.AvgTime) * 100
        
        # Memory improvement (positive = less memory)
        if ($this.OldResults.MemoryDelta -ne 0) {
            $this.MemoryImprovement = (($this.OldResults.MemoryDelta - $this.NewResults.MemoryDelta) / $this.OldResults.MemoryDelta) * 100
        }
        
        # Detailed improvements
        $this.Improvements["MinTime"] = (($this.OldResults.MinTime - $this.NewResults.MinTime) / $this.OldResults.MinTime) * 100
        $this.Improvements["MaxTime"] = (($this.OldResults.MaxTime - $this.NewResults.MaxTime) / $this.OldResults.MaxTime) * 100
        $this.Improvements["P95Time"] = (($this.OldResults.P95Time - $this.NewResults.P95Time) / $this.OldResults.P95Time) * 100
        $this.Improvements["P99Time"] = (($this.OldResults.P99Time - $this.NewResults.P99Time) / $this.OldResults.P99Time) * 100
    }
    
    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("COMPARISON RESULTS")
        $sb.AppendLine("=" * 50)
        $sb.AppendLine()
        
        $sb.AppendLine("Old Implementation:")
        $sb.AppendLine($this.OldResults.ToString())
        $sb.AppendLine()
        
        $sb.AppendLine("New Implementation:")
        $sb.AppendLine($this.NewResults.ToString())
        $sb.AppendLine()
        
        $sb.AppendLine("IMPROVEMENTS:")
        $sb.AppendLine("-" * 30)
        
        # Speed improvement
        $speedColor = if ($this.SpeedImprovement -gt 0) { "Green" } else { "Red" }
        $speedSymbol = if ($this.SpeedImprovement -gt 0) { "↑" } else { "↓" }
        $sb.AppendLine("Speed: $speedSymbol $([Math]::Abs($this.SpeedImprovement).ToString('F1'))%")
        
        # Memory improvement
        if ($this.MemoryImprovement -ne 0) {
            $memColor = if ($this.MemoryImprovement -gt 0) { "Green" } else { "Red" }
            $memSymbol = if ($this.MemoryImprovement -gt 0) { "↓" } else { "↑" }
            $sb.AppendLine("Memory: $memSymbol $([Math]::Abs($this.MemoryImprovement).ToString('F1'))%")
        }
        
        # Detailed metrics
        $sb.AppendLine()
        $sb.AppendLine("Detailed Metrics:")
        foreach ($metric in $this.Improvements.Keys | Sort-Object) {
            $improvement = $this.Improvements[$metric]
            $symbol = if ($improvement -gt 0) { "↑" } else { "↓" }
            $sb.AppendLine("  $metric`: $symbol $([Math]::Abs($improvement).ToString('F1'))%")
        }
        
        return $sb.ToString()
    }
}