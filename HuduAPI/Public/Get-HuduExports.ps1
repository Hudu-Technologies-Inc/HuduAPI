function Get-HuduExports {
    [CmdletBinding()]
    param(
        [int]$id
    )
    $resp = $null
    if ($null -ne $id -and $id -ge 1){
        $resp = Invoke-HuduRequest -Method 'GET' -Resource "/api/v1/exports/$id"
    } else {
        $resp = Invoke-HuduRequest -Method 'GET' -Resource '/api/v1/exports'
    }
    return ($resp.exports ?? $resp.export ?? $resp)
}