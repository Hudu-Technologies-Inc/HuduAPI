function Get-HuduFolders {
    <#
    .SYNOPSIS
    Get a list of Folders

    .DESCRIPTION
    Calls Hudu API to retrieve folders

    .PARAMETER Id
    Id of the folder

    .PARAMETER Name
    Filter by name

    .PARAMETER CompanyId
    Filter by company_id

    .EXAMPLE
    Get-HuduFolders

    #>
    [CmdletBinding()]
    Param (
        [Int]$Id = '',
        [String]$Name = '',
        [Alias('company_id')]
        [Int]$CompanyId = ''
    )
    $result = $null
    if ($id) {
        $result = Invoke-HuduRequest -Method get -Resource "/api/v1/folders/$id"
        return $result.Folder ?? $folder
    } else {
        $Params = @{}

        if ($CompanyId) { $Params.company_id = $CompanyId }
        if ($Name) { $Params.name = $Name }

        $HuduRequest = @{
            Method   = 'GET'
            Resource = '/api/v1/folders'
            Params   = $Params
        }
        $result = Invoke-HuduRequestPaginated -HuduRequest $HuduRequest
    }
    return $result.folders ?? $result.folder ?? $result
}
