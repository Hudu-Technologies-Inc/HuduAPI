$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue) + @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

$script:Cache = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
$script:Meta  = [System.Collections.Concurrent.ConcurrentDictionary[string,datetime]]::new()
$script:DefaultTtl = [TimeSpan]::FromMinutes(5)

function Set-CacheItem {
  param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)]$Value)
  [void]$script:Cache.AddOrUpdate($Key, $Value, { param($k,$old) $Value })
  [void]$script:Meta.AddOrUpdate($Key, (Get-Date), { param($k,$old) (Get-Date) })
}

function Get-CacheItem {
  param([Parameter(Mandatory)][string]$Key, [TimeSpan]$Ttl = $script:DefaultTtl)
  if (-not $script:Cache.TryGetValue($Key, [ref]$val)) { return $null }
  $stamp = if ($script:Meta.TryGetValue($Key, [ref]$ts)) { $ts } else { Get-Date '1900-01-01' }
  if ($Ttl -and ((Get-Date) - $stamp) -gt $Ttl) {
    [void]$script:Cache.TryRemove($Key, [ref]([object]$null))
    [void]$script:Meta.TryRemove($Key, [ref]([datetime]::MinValue))
    return $null
  }
  return $val
}

function Clear-CacheItem { param([string]$Key)
  [void]$script:Cache.TryRemove($Key, [ref]([object]$null))
  [void]$script:Meta.TryRemove($Key, [ref]([datetime]::MinValue))
}
function Clear-Cache { $script:Cache.Clear(); $script:Meta.Clear() }

foreach ($import in @($Public)) {
    try {
        . $import.FullName
    } catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}
Export-ModuleMember -Function $Public.BaseName -Alias *