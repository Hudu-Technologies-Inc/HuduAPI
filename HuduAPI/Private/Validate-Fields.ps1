
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

    # stale or cache miss -> live fetch (which will write-through cache)
    return Get-HuduAssetLayouts @PSBoundParameters
}
function Get-SanitizedAssetLayout {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$AssetLayoutId
    )
    $layout = $null

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

    if (-not $layout) {
        try {
            $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
            $layout = $layout.asset_layout ?? $layout
        } catch {
            return $null
        }
        if (-not $layout) { return $null }
    }
    # Detect if any label actually contains underscores
    $hasUnders = $false
    if ($layout.fields) {
        $hasUnders = @(
            $layout.fields |
            ForEach-Object { $_.label } |
            Where-Object { $_ -is [string] -and $_ -match '_' }
        ).Count -gt 0
    }

    if ($hasUnders) {
        write-host "warn- underscores present in layout"
        $updatedFields = $layout.fields | Remove-UnderscoresInFields -IsLayout

        $oldJson = $layout.fields    | ConvertTo-Json -Depth 50 -Compress
        $newJson = $updatedFields    | ConvertTo-Json -Depth 50 -Compress
        $changed = ($oldJson -ne $newJson)

        if ($changed -and $PSCmdlet.ShouldProcess("AssetLayout $AssetLayoutId","Replace underscores in labels")) {
            $null = Set-HuduAssetLayout -Id $AssetLayoutId -Fields $updatedFields
            $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
            $layout = $layout.asset_layout ?? $layout
            write-host "layout updated to not include underscores in fields."
        }
    }
    return $layout
}

function Get-ValidatedAssetFields {
    param (
        [array]$fields,
        [int]$assetLayoutId
    )
    $layout = Get-SanitizedAssetLayout -AssetLayoutId $assetLayoutId
    if (-not $layout) { return @() }

    $layoutLabelSet = @($layout.fields.label)

    $validatedFields = foreach ($field in $fields) {
        $matched = $false
        foreach ($layoutLabel in $layoutLabelSet) {
            if (Test-Equiv -A $field.label -B $layoutLabel) {
                # shallow clone to avoid mutating original
                $updated = @()
                if ($field -is [PSCustomObject]){
                    foreach ($p in $field.PSObject.Properties) {
                        $updated+= @{$p.Name = $p.Value}
                    }
                } else {
                    $updated = $field.clone()
                }
                $updated.label = $layoutLabel
                $matched = $true
                $updated
                break
            }
        }
        if (-not $matched) { $field }
    }
    return $($validatedFields | Remove-UnderscoresInFields)
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