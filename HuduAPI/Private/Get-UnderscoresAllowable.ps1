$underscoreAllowableVersionArray = @(([version]"2.37.1"),([version]"2.38.0"))

function Get-UnderscoresAllowable {
    $version = $null
    try {
        [version]$version = $([version]$(Get-HuduAppInfo).version)
    } catch {
        return $false
    }
    if ($version){
        return [bool]$($underscoreAllowableVersionArray -contains $version)
    }
    return $false
}

function Remove-UnderscoresInFields {
    param (
        [Array]$fields,
        [bool]$isLayout=$false
    )
    $cleansed = @()
    if (-not $fields){ return $null }
    if ($true -eq $isLayout){
        foreach ($f in $fields){
            $field = @{}
            foreach ($prop in $f.Keys | where-object {$_ -ne 'label'}){
                if (-not ([string]::IsNullOrWhiteSpace($prop)) -and -not [string]::IsNullOrWhiteSpace($f[$prop])){
                    $field[$prop]=$f[$prop]
                }
                $field["label"]="$($f["label"] -replace '_'," ")".Trim()
            }
            $cleansed+=$field
        }
    } else {
        foreach ($f in $fields){
            $field = @{}
            foreach ($kvpair in $f.GetEnumerator()){
                if (-not ([string]::IsNullOrWhiteSpace($kvpair.Name)) -and -not [string]::IsNullOrWhiteSpace("$($kvpair.Value)")){
                    $newKey = "$("$($kvpair.Name)" -replace "_"," ")".Trim()
                    $field[$newKey] = $kvpair.Value}
                }
            }
            $cleansed += $field
        }
    return $cleansed
}
