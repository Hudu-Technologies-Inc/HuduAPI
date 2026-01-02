function New-HuduFlag {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$FlagTypeId,

        [Parameter()]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateSet('Asset','Website','Article','AssetPassword','Company','Procedure','RackStorage','Network','IpAddress','Vlan','VlanZone')]
        [string]$FlagableType,

        [Parameter(Mandatory)]
        [int]$FlagableId
    )

    $bodyObj = @{
        flag = @{
            flag_type_id  = $FlagTypeId
            description   = $Description
            flagable_type = $FlagableType
            flagable_id   = $FlagableId
        }
    }

    $body = $bodyObj | ConvertTo-Json -Depth 99

    if ($PSCmdlet.ShouldProcess("$FlagableType Id=$FlagableId", "Create Flag (FlagTypeId=$FlagTypeId)")) {
        $resp = Invoke-HuduRequest -Method POST -Resource "/api/v1/flags" -Body $body
        return ($resp.flag ?? $resp)
    }
}
