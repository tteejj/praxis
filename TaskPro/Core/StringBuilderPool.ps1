# StringBuilderPool.ps1 - Pool for reusing StringBuilder instances to reduce memory allocations

class StringBuilderPool {
    static [System.Collections.Concurrent.ConcurrentQueue[System.Text.StringBuilder]]$Pool = [System.Collections.Concurrent.ConcurrentQueue[System.Text.StringBuilder]]::new()
    static [int]$MaxPoolSize = 50
    static [int]$MaxCapacity = 16384  # 16KB max capacity before discarding
    static [int]$CreatedCount = 0
    static [int]$ReusedCount = 0
    
    # Get a StringBuilder from the pool or create new one
    static [System.Text.StringBuilder] Get() {
        $sb = $null
        if ([StringBuilderPool]::Pool.TryDequeue([ref]$sb)) {
            $sb.Clear()  # Clear but keep capacity
            [StringBuilderPool]::ReusedCount++
        } else {
            $sb = [System.Text.StringBuilder]::new()
            [StringBuilderPool]::CreatedCount++
        }
        return $sb
    }
    
    # Get a StringBuilder with initial capacity
    static [System.Text.StringBuilder] Get([int]$initialCapacity) {
        $sb = $null
        if ([StringBuilderPool]::Pool.TryDequeue([ref]$sb)) {
            $sb.Clear()
            if ($sb.Capacity -lt $initialCapacity) {
                $sb.Capacity = $initialCapacity
            }
            [StringBuilderPool]::ReusedCount++
        } else {
            $sb = [System.Text.StringBuilder]::new($initialCapacity)
            [StringBuilderPool]::CreatedCount++
        }
        return $sb
    }
    
    # Return StringBuilder to pool for reuse
    static [void] Return([System.Text.StringBuilder]$sb) {
        if (-not $sb) { return }
        
        # Don't pool if too large (prevents memory bloat)
        if ($sb.Capacity -gt [StringBuilderPool]::MaxCapacity) {
            return
        }
        
        # Don't pool if we're at max capacity
        if ([StringBuilderPool]::Pool.Count -ge [StringBuilderPool]::MaxPoolSize) {
            return
        }
        
        $sb.Clear()
        [StringBuilderPool]::Pool.Enqueue($sb)
    }
    
    # Get pool statistics for debugging
    static [hashtable] GetStats() {
        return @{
            PoolSize = [StringBuilderPool]::Pool.Count
            MaxPoolSize = [StringBuilderPool]::MaxPoolSize
            Created = [StringBuilderPool]::CreatedCount
            Reused = [StringBuilderPool]::ReusedCount
            ReuseRate = if ([StringBuilderPool]::CreatedCount -eq 0) { 0 } else { 
                [Math]::Round(([StringBuilderPool]::ReusedCount / ([StringBuilderPool]::CreatedCount + [StringBuilderPool]::ReusedCount)) * 100, 2)
            }
        }
    }
    
    # Clear the pool (useful for testing or cleanup)
    static [void] Clear() {
        while ([StringBuilderPool]::Pool.TryDequeue([ref]$null)) {
            # Empty the queue
        }
    }
}

# Global helper functions for easier access
function Get-PooledStringBuilder {
    param([int]$initialCapacity = 256)
    
    if ($initialCapacity -gt 0) {
        return [StringBuilderPool]::Get($initialCapacity)
    } else {
        return [StringBuilderPool]::Get()
    }
}

function Return-PooledStringBuilder {
    param([System.Text.StringBuilder]$StringBuilder)
    [StringBuilderPool]::Return($StringBuilder)
}

function Get-StringBuilderPoolStats {
    return [StringBuilderPool]::GetStats()
}