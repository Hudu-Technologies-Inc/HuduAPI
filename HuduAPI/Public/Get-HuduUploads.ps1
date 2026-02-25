function Get-HuduUploads {
    <#
    .SYNOPSIS
    Get a list of uploads

    .DESCRIPTION
    Calls Hudu API to retrieve uploads

    .EXAMPLE
    Get-HuduUploads

    #>
    [CmdletBinding()]
    Param(
        [Int]$Id
    )

    if ($Id) {
        $Upload = Invoke-HuduRequest -Method Get -Resource "/api/v1/uploads/$Id"
    } else {
        [version]$script:Version = $script:Version ?? (Get-HuduAppInfo).version
        if ($script:Version -ge [version]("2.41.0")) {
            $Upload = Invoke-HuduRequestPaginated -hudurequest @{Method = "Get"; Resource = "/api/v1/uploads"; property = "uploads"}
        } else {
            $Upload = Invoke-HuduRequest -Method Get -Resource "/api/v1/uploads"
        }
    }
    return $Upload
}
 