function Assert-AllowedObjectType {
    param(
        [Parameter(Mandatory)][string]$InputType,
        [Parameter(Mandatory)][string[]]$AllowedCanonicals
    )

    $canonical = Get-ObjectTypeFromCononical $InputType
    if ($canonical -notin $AllowedCanonicals) {
        throw "Invalid type '$InputType' (canonical: '$canonical'). Allowed: $($AllowedCanonicals -join ', ')"
    }
    $true
}