function Assert-AllowedObjectType {
    param(
        [Parameter(Mandatory)][string]$InputType,
        [Parameter(Mandatory)][string[]]$AllowedCanonicals
    )

    $canonical = Get-ObjectTypeFromCononical $InputType  # accepts aliases; throws if unknown

    if ($canonical -notin $AllowedCanonicals) {
        throw "Invalid type '$InputType' (canonical: '$canonical'). Allowed: $($AllowedCanonicals -join ', ')"
    }

    $true
}