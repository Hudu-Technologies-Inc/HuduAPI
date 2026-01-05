
function Get-HuduFlagTypes {
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        # Get one
        [Parameter(ParameterSetName = 'ById')]
        [Alias('FlagTypeId','flag_type_id')]
        [int]$Id,

        # List filters
        [Parameter(ParameterSetName = 'List')]
        [string]$Name,

        [Parameter()]
        [ValidateSet(
            'Red','Blue','Green','Yellow','Purple','Orange',
            'LightPink','LightBlue','LightGreen','LightPurple',
            'LightOrange','LightYellow','White','Grey',
            IgnoreCase = $true
        )]
        [string]$Color,

        [string]$Slug,

        [string]$CreatedAt,

        [string]$UpdatedAt
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $resp = Invoke-HuduRequest -Method GET -Resource "/api/v1/flag_types/$Id"
            return ($resp.flag_type ?? $resp)
        }

        $params = @{}
        if ($PSBoundParameters.ContainsKey('Name'))      { $params.name       = $Name }
        if ($PSBoundParameters.ContainsKey('Color'))     { 
            $params.color      = $(Set-ColorFromCanonical -inputData $Color) 
        }
        if ($PSBoundParameters.ContainsKey('Slug'))      { $params.slug       = $Slug }
        if ($PSBoundParameters.ContainsKey('CreatedAt')) { $params.created_at = $CreatedAt }
        if ($PSBoundParameters.ContainsKey('UpdatedAt')) { $params.updated_at = $UpdatedAt }

        $req = @{
            Method   = 'GET'
            Resource = "/api/v1/flag_types"
            Params   = $params
        }

        Invoke-HuduRequestPaginated -HuduRequest $req -Property 'flag_types'
    }
}
