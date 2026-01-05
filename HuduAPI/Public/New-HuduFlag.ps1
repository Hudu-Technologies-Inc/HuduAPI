function New-HuduFlag {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$FlagTypeId,

        [Parameter()]
        [string]$Description,
        [Parameter(Mandatory)]
        [ValidateSet(
            'Asset','Website','Article','AssetPassword','Company',
            'Procedure','RackStorage','Network','IpAddress','Vlan','VlanZone',
            IgnoreCase = $true
        )]
        [Alias('flaggabletype','flaggable_type','flagabletype','Flag_type','FlagType')]
        [string]$Flagable_Type,

        [Parameter(Mandatory)]
        [Alias("FlaggableId","flaggable_id","flagableid")]
        [int]$flagable_id
    )
    $flagable_type = Set-FlagableFromCanonical -inputData $flagable_type

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
