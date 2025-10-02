function Copy-ToHashtable {
  param($obj)
  if ($obj -is [System.Collections.IDictionary]) { return @{} + $obj } # shallow copy
  $h = @{}
  foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
  return $h
}

function Normalize-Label([string]$s) {
  if (-not $s) { return '' }
  
  if ($null -eq $s) { return $s }
    ($s -replace '[_\s]+',' ' ).Trim().ToLowerInvariant() # treat underscores/spaces the same, case-insensitive
    $t = $s -replace '_+', ' '       # collapse multiple underscores in one go
    $t = $t -replace '\s+', ' '               # collapse multiple spaces
    return $t.Trim()
}

function Set-LayoutsCacheMarkedDirty {
<#
.SYNOPSIS
Mark the Asset Layouts cache as stale (or wipe it).

.PARAMETER Hard
Also clears cached data and the legacy $script:AssetLayouts list.
#>
    [CmdletBinding()]
    param([switch]$Hard)

    if (-not $script:AssetLayoutsCache) {
        $script:AssetLayoutsCache = [pscustomobject]@{
            Data     = @()
            CachedAt = $null
        }
        $script:AssetLayouts = @()
        return $script:AssetLayoutsCache
    }

    # Mark NOT fresh (stale) but keep data by default
    $script:AssetLayoutsCache.CachedAt = $null

    if ($Hard) {
        $script:AssetLayoutsCache.Data = @()
        $script:AssetLayouts = @()
    }

    return $script:AssetLayoutsCache
}
function Add-HuduAssetLayoutsToCache {
<#
.SYNOPSIS
Merge asset layout objects into the in-memory cache.

.DESCRIPTION
Adds or replaces asset layout records in $script:AssetLayoutsCache.Data keyed by Id.
By default, does NOT update the cache timestamp (CachedAt). Pass -MarkFresh to stamp now.
Also keeps $script:AssetLayouts (used by completer) in sync.

.PARAMETER Layout
One or more layout objects. Accepts:
 - A raw layout object (with properties like id, name, fields, slug, …), or
 - An API wrapper object with an 'asset_layout' property (will be unwrapped).

.PARAMETER MarkFresh
If present, sets $script:AssetLayoutsCache.CachedAt = (Get-Date) after merging.

.OUTPUTS
The updated cache object ($script:AssetLayoutsCache).

.EXAMPLE
# After updating a single layout live, merge it into cache without touching timestamp
$layout = Get-HuduAssetLayouts -Id 15
Add-HuduAssetLayoutsToCache -Layout $layout

.EXAMPLE
# Bulk-merge and mark the cache fresh (full-list semantics)
$all = Get-HuduAssetLayouts
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [object[]]$Layout,
        [switch]$MarkFresh
    )

    begin {
        $buffer = New-Object System.Collections.Generic.List[object]
    }
    process {
        foreach ($item in $Layout) {
            # Unwrap { asset_layout = <obj> } responses if present
            if ($item -and $item.PSObject.Properties.Match('asset_layout')) {
                $item = $item.asset_layout
            }
            if (-not $item) { continue }

            # Normalize ID to int when possible (defensive)
            if ($item.PSObject.Properties.Match('id') -and $item.id -isnot [int]) {
                try { $item.id = [int]$item.id } catch { }
            }

            $buffer.Add($item)
        }
    }
    end {
        if (-not $script:AssetLayoutsCache) {
            $script:AssetLayoutsCache = [pscustomobject]@{
                Data     = @()
                CachedAt = $null
            }
        }

        # Build a map of existing by id, replace or add new/updated
        $byId = @{}
        foreach ($existing in ($script:AssetLayoutsCache.Data ?? @())) {
            $byId[[string]$existing.id] = $existing
        }
        foreach ($item in $buffer) {
            if ($item -and $item.PSObject.Properties.Match('id')) {
                $byId[[string]$item.id] = $item
            }
        }

        # Sort by name
        $sorted = $byId.Values | Sort-Object -Property @{Expression = { $_.name }; Ascending = $true}

        $script:AssetLayoutsCache.Data = @($sorted)
        if ($MarkFresh) {
            $script:AssetLayoutsCache.CachedAt = Get-Date
        }

        # Keep legacy script layout cache for completer
        $script:AssetLayouts = $script:AssetLayoutsCache.Data

        return $script:AssetLayoutsCache
    }
}

function Get-HuduAssetLayoutsCached {
    [CmdletBinding()]
    Param (
        [String]$Name,
        [Alias('id', 'layout_id')]
        [int]$LayoutId,
        [String]$Slug
    )

    $now     = Get-Date
    $isFresh = $false
    if ($script:AssetLayoutsCache) {
        $isFresh = ($null -ne $script:AssetLayoutsCache.CachedAt) -and
                   (($now - $script:AssetLayoutsCache.CachedAt) -lt $script:AssetLayoutsCacheTtl)
    }

    if ($isFresh) {
        if ($LayoutId) {
            $hit = $script:AssetLayoutsCache.Data | Where-Object { $_.id -eq $LayoutId }
            if ($hit) { return $hit }
            # miss in fresh cache -> fetch live
        } elseif ($Name -or $Slug) {
            $filtered = $script:AssetLayoutsCache.Data
            if ($Name) { $filtered = $filtered | Where-Object { $_.name -eq $Name } }
            if ($Slug) { $filtered = $filtered | Where-Object { $_.slug -eq $Slug } }
            return $filtered
        } else {
            return $script:AssetLayoutsCache.Data
        }
    }

    return Get-HuduAssetLayouts @PSBoundParameters
}
function Get-SanitizedAssetLayout {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$AssetLayoutId
    )
    $updatedFields = @()
    $ReplaceWith=" "
    $rxU = [regex]'_+'
    $rxS = [regex]'\s{2,}'
    $layout   = $null
    $now      = Get-Date
    $isFresh  = $false

    # ---------- Try cache first ----------
    if ($script:AssetLayoutsCache -and $script:AssetLayoutsCache.CachedAt) {
        $isFresh = (($now - $script:AssetLayoutsCache.CachedAt) -lt $script:AssetLayoutsCacheTtl)
        if ($isFresh) {
            $layout = $script:AssetLayoutsCache.Data | Where-Object { $_.id -eq $AssetLayoutId }
        }
    }

    # ---------- LIVE FETCH PATH (no cache, stale cache, or cache miss) ----------
    if (-not $layout) {
        try {
            $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
            $layout = $layout.asset_layout ?? $layout
        } catch {
            return $null
        }
      }
    if (-not $layout -or -not $layout.fields) { return $layout }

  # Build sanitized fields as hashtable[]
  $updatedFields = @()
  $changed = $false
  foreach ($f in @($layout.fields)) {
    $h = Copy-ToHashtable $f
    if ($h.ContainsKey('label') -and $h['label'] -is [string]) {
      $new = $rxS.Replace( ($rxU.Replace($h['label'], $ReplaceWith)), ' ' ).Trim()
      if ($new -ne $h['label']) { $changed = $true }
      $h['label'] = $new
    }
    $updatedFields += ,$h
  }

  if ($changed -and $PSCmdlet.ShouldProcess("AssetLayout $AssetLayoutId","Replace underscores in field labels")) {
    $body = @{ asset_layout = @{ fields = $updatedFields } } | ConvertTo-Json -Depth 100 -Compress
    [void](Invoke-HuduRequest -Resource "/api/v1/asset_layouts/$AssetLayoutId" -Method PUT -Body $body)
    # Re-fetch & update cache
    $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
    $layout = $layout.asset_layout ?? $layout
  }

  return $layout
}
function Get-LayoutLabelMap {
  param([Parameter(Mandatory)][int]$AssetLayoutId)

  $layout = Get-SanitizedAssetLayout -AssetLayoutId $AssetLayoutId
  $map = @{}
  foreach ($f in @($layout.fields)) {
    $lbl = if ($f -is [System.Collections.IDictionary]) { $f['label'] } else { $f.label }
    if ($lbl) { $map[(Normalize-Label $lbl)] = $lbl } # normalized key -> canonical label
  }
  return $map
}
function Convert-AssetFieldsToCanonical {
  param(
    [Parameter(Mandatory)][array]$Fields,
    [Parameter(Mandatory)][int]$AssetLayoutId,
    [switch]$DropUnmatched,
    [switch]$DropNull
  )
  $labelMap = Get-LayoutLabelMap -AssetLayoutId $AssetLayoutId
  function Is-Nullish([object]$v) {
    if ($null -eq $v) { return $true }
    if ($v -is [string]) { return [string]::IsNullOrWhiteSpace($v) }
    return $false
  }

  $out = @()
  foreach ($item in @($Fields)) {
    $h = Copy-ToHashtable $item
    $new = @{}
    foreach ($k in @($h.Keys)) {
      if ($DropNull -and (Is-Nullish $h[$k])) { continue }

      $norm = Normalize-Label $k
      if ($labelMap.ContainsKey($norm)) {
        $new[$labelMap[$norm]] = $h[$k]     # rename key to canonical label
      } elseif (-not $DropUnmatched) {
        $new[$k] = $h[$k]
      }
    }

    if ($new.Count -gt 0) { $out += ,$new }
  }

  return ,$out   # ensure hashtable[]
}
function Remove-UnderscoresInFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Fields,

        # Only clean the "label" property in asset layout field objects
        [switch]$IsLayout,

        # Default is a space; coerced to string to prevent $true -> "True"
        [string]$ReplaceWith = ' ',

        # Optionally drop null/empty values
        [switch]$DropNullValues
    )

    begin {
        # Coerce once; guarantees string even if caller passed a bool accidentally
        $Replacement = [string]$ReplaceWith

        function As-Enumerable($x) {
            if ($null -eq $x) { @() }
            elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) { $x }
            else { ,$x }
        }
        function Get-Pairs($obj) {
            if ($obj -is [System.Collections.IDictionary]) {
                $obj.GetEnumerator() | ForEach-Object {
                    [PSCustomObject]@{ Name = $_.Key; Value = $_.Value }
                }
            } else {
                $obj.PSObject.Properties | ForEach-Object {
                    [PSCustomObject]@{ Name = $_.Name; Value = $_.Value }
                }
            }
        }
        function Is-Empty([object]$v) {
            if ($null -eq $v) { return $true }
            if ($v -is [string]) { return [string]::IsNullOrWhiteSpace($v) }
            return $false
        }
    }

    process {
        $out = @()

        foreach ($f in (As-Enumerable $Fields)) {
            if ($null -eq $f) { continue }

            if ($IsLayout) {
                # Only touch "label"
                $new = [ordered]@{}
                foreach ($p in Get-Pairs $f) {
                    if ($p.Name -eq 'label' -and $p.Value -is [string]) {
                        $new['label'] = $p.Value.Replace('_', $Replacement).Trim()
                    } else {
                        if ($DropNullValues) {
                            if (-not (Is-Empty $p.Value)) { $new[$p.Name] = $p.Value }
                        } else {
                            $new[$p.Name] = $p.Value
                        }
                    }
                }
                $out += $new
            } else {
                # Transform ALL keys
                $new = [ordered]@{}
                foreach ($p in Get-Pairs $f) {
                    $newKey = ($p.Name.ToString()).Replace('_', $Replacement).Trim()
                    if ($DropNullValues) {
                        if (-not (Is-Empty $p.Value)) { $new[$newKey] = $p.Value }
                    } else {
                        $new[$newKey] = $p.Value
                    }
                }
                $out += $new
            }
        }

        $out
    }
}