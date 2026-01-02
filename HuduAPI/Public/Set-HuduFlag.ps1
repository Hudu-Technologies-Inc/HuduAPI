
function Set-HuduFlag {
    <#
    .SYNOPSIS
    Update a flag

    .DESCRIPTION
    Uses Hudu API to update a Flag. If updating the flagable association,
    flagable_type must be valid and the record must exist.

    .PARAMETER Id
    ID of the flag to update

    .PARAMETER FlagTypeId
    Updated flag type ID

    .PARAMETER Description
    Updated description

    .PARAMETER FlagableType
    Updated flagable type (Asset, Website, Article, AssetPassword, Company, Procedure, RackStorage, Network, IpAddress, Vlan, VlanZone)

    .PARAMETER FlagableId
    Updated flagable record ID

    .EXAMPLE
    Set-HuduFlag -Id 10 -Description "Updated flag description" -FlagTypeId 2

    .EXAMPLE
    Set-HuduFlag -Id 10 -FlagableType Asset -FlagableId 123
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Alias('flag_type_id')]
        [int]$FlagTypeId,

        [string]$Description = '',

        [Alias('flagable_type')]
        [ValidateSet('Asset','Website','Article','AssetPassword','Company','Procedure','RackStorage','Network','IpAddress','Vlan','VlanZone')]
        [string]$FlagableType = '',

        [Alias('flagable_id')]
        [int]$FlagableId
    )

    $Object = Get-HuduFlags -Id $Id
    if (-not $Object) { return $null }

    $Flag = [ordered]@{ flag = $Object }

    if ($PSBoundParameters.ContainsKey('FlagTypeId')) {
        $Flag.flag.flag_type_id = $FlagTypeId
    }

    if ($Description) {
        $Flag.flag.description = $Description
    }

    if ($FlagableType) {
        $Flag.flag.flagable_type = $FlagableType
    }

    if ($PSBoundParameters.ContainsKey('FlagableId')) {
        $Flag.flag.flagable_id = $FlagableId
    }

    $JSON = $Flag | ConvertTo-Json -Depth 10

    if ($PSCmdlet.ShouldProcess($Id)) {
        Invoke-HuduRequest -Method PUT -Resource "/api/v1/flags/$Id" -Body $JSON
    }
}