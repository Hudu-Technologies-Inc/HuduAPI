function Get-SanitizedAssetLayout {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$AssetLayoutId
    )
    $layout = $null
    try {
        $layout = get-huduassetlayout -id $assetlayoutid
        $layout = $layout.asset_layout ?? $layout
    } catch {return $null}
    if (-not $layout) { return $null }

    # Detect if any label actually contains underscores
    $hasUnders = $false
    if ($layout.fields) {
        $hasUnders = @(
            $layout.fields | ForEach-Object { $_.label } |
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
    param(
        [array]$Fields,
        [int]$AssetLayoutId
    )
    function Copy-ToHashtable {
        param($obj)
        if ($obj -is [System.Collections.IDictionary]) {
            return $obj.Clone()           # shallow clone of hashtable
        }
        $h = @{}
        foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
        return $h
    }

    function Normalize-Label([string]$s) {
        return ($s ?? '').Trim().ToLowerInvariant()
    }

    $layout = Get-SanitizedAssetLayout -AssetLayoutId $AssetLayoutId
    if (-not $layout -or -not $layout.fields) { return @() }

    $canon = @{}
    foreach ($lf in $layout.fields) {
        $lbl = if ($lf -is [System.Collections.IDictionary]) { $lf['label'] } else { $lf.label }
        if ($lbl) { $canon[(Normalize-Label $lbl)] = $lbl }
    }

    $validated = foreach ($field in $Fields) {
        # Get current label from either type
        $cur = if ($field -is [System.Collections.IDictionary]) { $field['label'] } else { $field.label }
        $key = Normalize-Label $cur
        if ($canon.ContainsKey($key)) {
            $clone = Copy-ToHashtable $field
            $clone['label'] = $canon[$key]
            $clone
        }
        
    }

    $validated | Remove-UnderscoresInFields
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