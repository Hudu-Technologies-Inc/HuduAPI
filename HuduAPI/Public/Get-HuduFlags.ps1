function Get-HuduFlags {
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        # Get one
        [Parameter(ParameterSetName = 'ById', Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FlagId')]
        [int]$Id,

        # List filters
        [Parameter(ParameterSetName = 'List')]
        [int]$FlagTypeId,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('Asset','Website','Article','AssetPassword','Company','Procedure','RackStorage','Network','IpAddress','Vlan','VlanZone')]
        [string]$FlagableType,

        [Parameter(ParameterSetName = 'List')]
        [int]$FlagableId,

        [Parameter(ParameterSetName = 'List')]
        [string]$Description,

        [Parameter(ParameterSetName = 'List')]
        [string]$CreatedAt,

        [Parameter(ParameterSetName = 'List')]
        [string]$UpdatedAt,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Page,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 1000
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $resp = Invoke-HuduRequest -Method GET -Resource "/api/v1/flags/$Id"
            return ($resp.flag ?? $resp)
        }

        $params = @{}
        if ($PSBoundParameters.ContainsKey('FlagTypeId'))   { $params.flag_type_id  = $FlagTypeId }
        if ($PSBoundParameters.ContainsKey('FlagableType')) { $params.flagable_type = $FlagableType }
        if ($PSBoundParameters.ContainsKey('FlagableId'))   { $params.flagable_id   = $FlagableId }
        if ($PSBoundParameters.ContainsKey('Description'))  { $params.description   = $Description }
        if ($PSBoundParameters.ContainsKey('CreatedAt'))    { $params.created_at    = $CreatedAt }
        if ($PSBoundParameters.ContainsKey('UpdatedAt'))    { $params.updated_at    = $UpdatedAt }

        if ($PSBoundParameters.ContainsKey('Page')) {
            $params.page = $Page
            $params.page_size = $PageSize
            $resp = Invoke-HuduRequest -Method GET -Resource "/api/v1/flags" -Params $params
            return ($resp.flags ?? $resp)
        }

        $req = @{
            Method   = 'GET'
            Resource = "/api/v1/flags"
            Params   = $params
        }

        Invoke-HuduRequestPaginated -HuduRequest $req -Property 'flags' -PageSize $PageSize
    }
}
