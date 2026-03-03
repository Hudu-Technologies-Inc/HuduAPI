function Get-AllowedTypeAliases {
    param(
        [Parameter(Mandatory)]
        [string[]]$AllowedTypes,
        [bool]$IncludeCanonical=$true
    )
    $first = $AllowedTypes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if ($first) { [void](Get-ObjectTypeFromCononical $first) }

    $canonicals = $(foreach ($t in $AllowedTypes) {
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        Get-ObjectTypeFromCononical $t
    }) | Select-Object -Unique

    $vals = foreach ($c in $canonicals) {
        if ($IncludeCanonical) { $c }
        foreach ($a in $script:FlaggableTypeMap[$c]) { $a }
    }

    $vals |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() } |
        Select-Object -Unique
}