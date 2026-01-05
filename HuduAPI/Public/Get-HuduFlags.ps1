function Get-HuduFlags {
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        # Get one
        [Parameter(ParameterSetName = 'ById')]
        [Alias('FlagId','flag_id')]
        [int]$Id,

        # List filters
        [Parameter(ParameterSetName = 'List')]
        [Alias("Flag_Type_ID","FlagType_ID","Flag_TypeId")]
        [int]$FlagTypeId,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('Asset','Website','Article','AssetPassword','Company','Procedure','RackStorage','Network','IpAddress','Vlan','VlanZone')]
        [Alias('flagabletype',"flaggable_type","flaggabletype","Flag_type","FlagType")]
        [string]$flagable_type,

        [Parameter(ParameterSetName = 'List')]
        [Alias("FlaggableId","flaggable_id","flagableid")]
        [int]$flagable_id,

        [Parameter(ParameterSetName = 'List')]
        [string]$Description,

        [Parameter(ParameterSetName = 'List')]
        [string]$CreatedAt,

        [Parameter(ParameterSetName = 'List')]
        [string]$UpdatedAt
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $resp = Invoke-HuduRequest -Method GET -Resource "/api/v1/flags/$Id"
            return ($resp.flag ?? $resp ?? $null)
        }

        $params = @{}
        if ($PSBoundParameters.ContainsKey('FlagTypeId'))   { $params.flag_type_id  = $FlagTypeId }
        if ($PSBoundParameters.ContainsKey('flagable_type')) {
            $flagable_type = Set-FlagableFromCanonical -inputData $flagable_type
            $params.flagable_type = $flagable_type
        }
        if ($PSBoundParameters.ContainsKey('flagable_id'))   { $params.flagable_id   = $flagable_id }
        if ($PSBoundParameters.ContainsKey('Description'))  { $params.description   = $Description }
        if ($PSBoundParameters.ContainsKey('CreatedAt'))    { $params.created_at    = $CreatedAt }
        if ($PSBoundParameters.ContainsKey('UpdatedAt'))    { $params.updated_at    = $UpdatedAt }
        $req = @{
            Method   = 'GET'
            Resource = "/api/v1/flags"
            Params   = $params
        }

        $resp = Invoke-HuduRequestPaginated -HuduRequest $req -Property 'flags'
        return ($resp.flags ?? $resp ?? $null)
    }
}
