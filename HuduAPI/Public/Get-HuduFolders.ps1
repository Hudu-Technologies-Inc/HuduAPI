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

    .PARAMETER folder_type


    .EXAMPLE
    Get-HuduFolders

    #>
    [CmdletBinding()]
    Param (
        [Int]$Id = '',
        [String]$Name = '',
        [Alias('company_id')]
        [Int]$CompanyId = '',
        [Alias('foldertype','type')]
        [ValidateSet("Article", "Photo",IgnoreCase = $true)]
        [string]$folder_type = $null
    )

    if ($id) {
        $Folder = Invoke-HuduRequest -Method get -Resource "/api/v1/folders/$id"
        return $Folder.Folder
    } else {
        $Params = @{}

        if ($CompanyId) { $Params.company_id = $CompanyId }
        if ($Name) { $Params.name = $Name }

        if (-not ([string]::isnullorwhitespace($folder_type)) -and [version]$($script:Version ?? (Get-HuduAppInfo).version) -gt [version]'2.39.0'){
            $Params.folder_type = "$folderType".ToLower()
        }

        $HuduRequest = @{
            Method   = 'GET'
            Resource = '/api/v1/folders'
            Params   = $Params
        }
        Invoke-HuduRequestPaginated -HuduRequest $HuduRequest -Property folders
    }
}
