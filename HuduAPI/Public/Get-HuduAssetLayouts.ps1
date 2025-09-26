function Get-HuduAssetLayouts {
    <#
    .SYNOPSIS
    Get a list of Asset Layouts

    .DESCRIPTION
    Call Hudu API to retrieve asset layouts for server

    .PARAMETER Name
    Filter by name of Asset Layout

    .PARAMETER LayoutId
    Id of Asset Layout

    .PARAMETER Slug
    Filter by url slug

    .EXAMPLE
    Get-HuduAssetLayouts -Name 'Contacts'

    #>
    [CmdletBinding()]
    Param (
        [String]$Name,
        [Alias('id', 'layout_id')]
        [int]$LayoutId,
        [String]$Slug
    )

    $HuduRequest = @{
        Resource = '/api/v1/asset_layouts'
        Method   = 'GET'
    }

    if ($LayoutId) {
        $HuduRequest.Resource = '{0}/{1}' -f $HuduRequest.Resource, $LayoutId
        $result = Invoke-HuduRequest @HuduRequest
        return $result.asset_layout ?? $result
    } else {
        $Params = @{}
        if ($Name) { $Params.name = $Name }
        if ($Slug) { $Params.slug = $Slug }
        $HuduRequest.Params = $Params

        $result = Invoke-HuduRequestPaginated -HuduRequest $HuduRequest -PageSize 25

        if (!$Name -and !$Slug) {
            $script:AssetLayouts = $result | Sort-Object -Property name
        }
        # account for singular or plural propname
        return $result.asset_layouts ?? $result.asset_layout ?? $result
    }
}
