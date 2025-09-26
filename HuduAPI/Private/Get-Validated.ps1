
function To-HashtableArray {
  param($items)
  ,(@($items) | ForEach-Object { Copy-ToHashtable $_ })
}
function Get-LayoutLabelMap {
  param([Parameter(Mandatory)][int]$AssetLayoutId)

  $layout = Set-UnderscoresSanitizedLayout -AssetLayoutId $AssetLayoutId
  $map = @{}
  foreach ($f in @($layout.fields)) {
    $lbl = if ($f -is [System.Collections.IDictionary]) { $f['label'] } else { $f.label }
    if ($lbl) { $map[(Normalize-Label $lbl)] = $lbl } # normalized key -> canonical label
  }
  return $map
}

function Copy-ToHashtable {
  param($obj)
  if ($obj -is [System.Collections.IDictionary]) { return @{} + $obj } # shallow copy
  $h = @{}
  foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
  return $h
}

function Normalize-Label([string]$s) {
  if (-not $s) { return '' }
  # treat underscores/spaces the same, case-insensitive
  ($s -replace '[_\s]+',' ' ).Trim().ToLowerInvariant()
}
function Set-UnderscoresSanitizedLayout {
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][int]$AssetLayoutId, [string]$ReplaceWith = ' ')

  $rxU = [regex]'_+'
  $rxS = [regex]'\s{2,}'

  # fetch (use the cmdlet that actually works in your env)
  $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
  $layout = $layout.asset_layout ?? $layout
  if (-not $layout -or -not $layout.fields) { return $layout }

  # build sanitized fields as Hashtable[]
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
    # body MUST be hashtable-of-hashtable, not dot-notation
    $body = @{ asset_layout = @{ fields = $updatedFields } } | ConvertTo-Json -Depth 100 -Compress
    [void](Invoke-HuduRequest -Resource "/api/v1/asset_layouts/$AssetLayoutId" -Method PUT -Body $body)

    # re-fetch canonical shape
    $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
    $layout = $layout.asset_layout ?? $layout
  }

  return $layout
}

function Convert-AssetFieldsToCanonical {
  param(
    [Parameter(Mandatory)][array]$Fields,      # PSCustomObject[] or Hashtable[]
    [Parameter(Mandatory)][int]$AssetLayoutId,
  )

  $labelMap = Get-LayoutLabelMap -AssetLayoutId $AssetLayoutId

  $out = @()
  foreach ($item in @($Fields)) {
    $h = Copy-ToHashtable $item
    $new = @{}

    foreach ($k in @($h.Keys)) {
      $norm = Normalize-Label $k
      if ($labelMap.ContainsKey($norm)) {
        $new[$labelMap[$norm]] = $h[$k]     # rename key to canonical label
      } 
    }

    if ($new.Count -gt 0) { $out += ,$new }
  }

  return ,$out   # ensure hashtable[]
}
