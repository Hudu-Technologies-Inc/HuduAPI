
function Get-HuduFlagTypes {
<#
.SYNOPSIS
Gets Flag Types from Hudu.

.DESCRIPTION
Retrieves Flag Types by ID or lists Flag Types with optional filtering. When listing,
filters match exact values for name/color/slug when provided. Results are paginated.

.PARAMETER Id
Return a single Flag Type by ID.

.PARAMETER Name
Filter by exact Flag Type name.

.PARAMETER Color
Filter by exact color value (canonicalized to Hudu).

.PARAMETER Slug
Filter by exact slug value.

.EXAMPLE
Get-HuduFlagTypes
# List all flag types

.EXAMPLE
Get-HuduFlagTypes -Name "Security Risk"
# Find the "Security Risk" flag type

.EXAMPLE
Get-HuduFlagTypes -Id 12
# Get a specific flag type by ID

.NOTES
API Endpoints:
- GET /api/v1/flag_types
- GET /api/v1/flag_types/{id}
#>

    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(ParameterSetName = 'ById')]
        [Alias('FlagTypeId','flag_type_id')]
        [int]$Id,

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

        [string]$Slug
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

        $req = @{
            Method   = 'GET'
            Resource = "/api/v1/flag_types"
            Params   = $params
        }

        Invoke-HuduRequestPaginated -HuduRequest $req -Property 'flag_types'
    }
}
