
function Get-HuduFlagTypes {
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        # Get one
        [Parameter(ParameterSetName = 'ById', Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FlagTypeId')]
        [int]$Id,

        # List filters
        [Parameter(ParameterSetName = 'List')]
        [string]$Name,

        [Parameter(ParameterSetName = 'List')]
        [string]$Color,

        [Parameter(ParameterSetName = 'List')]
        [string]$Slug,

        [Parameter(ParameterSetName = 'List')]
        [string]$CreatedAt,

        [Parameter(ParameterSetName = 'List')]
        [string]$UpdatedAt,

        # If you want to allow single-page retrieval sometimes
        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Page,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 1000
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $resp = Invoke-HuduRequest -Method GET -Resource "/api/v1/flag_types/$Id"
            return ($resp.flag_type ?? $resp)
        }

        $params = @{}
        if ($PSBoundParameters.ContainsKey('Name'))      { $params.name       = $Name }
        if ($PSBoundParameters.ContainsKey('Color'))     { $params.color      = $Color }
        if ($PSBoundParameters.ContainsKey('Slug'))      { $params.slug       = $Slug }
        if ($PSBoundParameters.ContainsKey('CreatedAt')) { $params.created_at = $CreatedAt }
        if ($PSBoundParameters.ContainsKey('UpdatedAt')) { $params.updated_at = $UpdatedAt }

        # If Page explicitly provided, do a single request for that page
        if ($PSBoundParameters.ContainsKey('Page')) {
            $params.page = $Page
            $params.page_size = $PageSize
            $resp = Invoke-HuduRequest -Method GET -Resource "/api/v1/flag_types" -Params $params
            return ($resp.flag_types ?? $resp)
        }

        $req = @{
            Method   = 'GET'
            Resource = "/api/v1/flag_types"
            Params   = $params
        }

        Invoke-HuduRequestPaginated -HuduRequest $req -Property 'flag_types' -PageSize $PageSize
    }
}
