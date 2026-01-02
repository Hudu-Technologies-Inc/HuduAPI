function New-HuduFlag {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$FlagTypeId,

        [Parameter()]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateSet('Asset','Website','Article','AssetPassword','Company','Procedure','RackStorage','Network','IpAddress','Vlan','VlanZone')]
        [Alias('flagabletype',"flaggable_type","flaggabletype","Flag_type","FlagType")]
        [string]$flagable_type,

        [Parameter(Mandatory)]
        [Alias("FlaggableId","flaggable_id","flagableid")]
        [int]$flagable_id
    )

    $bodyObj = @{
        flag = @{
            flag_type_id  = $FlagTypeId
            description   = $Description
            flagable_type = $flagable_type
            flagable_id   = $flagable_id
        }
    }

    $body = $bodyObj | ConvertTo-Json -Depth 99

    if ($PSCmdlet.ShouldProcess("$flagable_type Id=$flagable_id", "Create Flag (FlagTypeId=$FlagTypeId)")) {
        $resp = Invoke-HuduRequest -Method POST -Resource "/api/v1/flags" -Body $body
        return ($resp.flag ?? $resp)
    }
}
