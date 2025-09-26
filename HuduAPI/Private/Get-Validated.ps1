function Get-UnderscoresReplacedFields {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$AssetLayoutId
    )
    $cacheKey = "assetlayout:$AssetLayoutId"
    $layout = Get-CacheItem -Key $cacheKey
    if (-not $layout) {
        $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
        $layout = $layout.asset_layout ?? $layout
    }
    if (-not $layout) { return $null }

    # Detect if any label actually contains underscores
    $hasUnders = @(
        $layout.fields |
        ForEach-Object { $_.label } |
        Where-Object { $_ -is [string] -and $_ -match '_' }
    ).Count -gt 0

    if ($hasUnders) {
        $updatedFields = $layout.fields | Remove-UnderscoresInFields -IsLayout

        $oldJson = $layout.fields    | ConvertTo-Json -Depth 50 -Compress
        $newJson = $updatedFields    | ConvertTo-Json -Depth 50 -Compress
        $changed = ($oldJson -ne $newJson)

        if ($changed -and $PSCmdlet.ShouldProcess("AssetLayout $AssetLayoutId","Replace underscores in labels")) {
            $null = Set-HuduAssetLayout -Id $AssetLayoutId -Fields $updatedFields
            $layout = Get-HuduAssetLayouts -Id $AssetLayoutId
            $layout = $layout.asset_layout ?? $layout
        }
    }

    Set-CacheItem -Key $cacheKey -Value $layout
    return $layout
}

function Get-ValidatedAssetFields {
    param (
        [array]$fields,
        [int]$assetLayoutId
    )
    $layout = Get-UnderscoresReplacedFields -AssetLayoutId $assetLayoutId
    $layoutlabelset = $layout.fields.label
    $validatedFields = @()
    foreach ($field in $fields){
        foreach ($layoutLabel in $layoutlabelset) {
            if (test-equiv -A $field.label -B $label){
                $updated = $field
                $updated.label = $layoutLabel
                $validatedFields += $updated
            }
        }
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