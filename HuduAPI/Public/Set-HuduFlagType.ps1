function Set-HuduFlagType {
    <#
    .SYNOPSIS
    Update a flag type

    .DESCRIPTION
    Uses Hudu API to update a Flag Type

    .PARAMETER Id
    ID of the flag type to update

    .PARAMETER Name
    Updated name

    .PARAMETER Color
    Updated color (e.g. "Red" or "#FF0000" depending on your instance conventions)

    .EXAMPLE
    Set-HuduFlagType -Id 1 -Name "Updated Flag Type" -Color "Green"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [string]$Name = '',

        [string]$Color = ''
    )

    $Object = Get-HuduFlagType -Id $Id
    if (-not $Object) { return $null }

    $FlagType = [ordered]@{ flag_type = $Object }

    if ($Name)  { $FlagType.flag_type.name  = $Name }
    if ($Color) { $FlagType.flag_type.color = $Color }

    $JSON = $FlagType | ConvertTo-Json -Depth 10

    if ($PSCmdlet.ShouldProcess($Id)) {
        Invoke-HuduRequest -Method PUT -Resource "/api/v1/flag_types/$Id" -Body $JSON
    }
}
