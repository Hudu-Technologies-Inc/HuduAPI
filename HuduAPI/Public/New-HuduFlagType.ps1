function New-HuduFlagType {
<#
.SYNOPSIS
Creates a new Flag Type.

.DESCRIPTION
Creates a Flag Type (name + color) that can be applied to objects via New-HuduFlag.
Flag Types are reusable and are referenced by ID (flag_type_id) when creating Flags.

.PARAMETER Name
Display name for the Flag Type (e.g., "Needs Review", "Security Risk", "Onboarding").

.PARAMETER Color
Color name (canonicalized to Hudu). Controls the UI color used when displaying the flag.

.EXAMPLE
New-HuduFlagType -Name "Security Risk" -Color Red

.NOTES
API Endpoint: POST /api/v1/flag_types
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'Red','Blue','Green','Yellow','Purple','Orange',
            'LightPink','LightBlue','LightGreen','LightPurple',
            'LightOrange','LightYellow','White','Grey',
            IgnoreCase = $true
        )]
        [string]$Color
    )
    $Color = Set-ColorFromCanonical -inputData $Color

    $bodyObj = @{
        flag_type = @{
            name  = $Name
            color = $Color
        }
    }

    $body = $bodyObj | ConvertTo-Json -Depth 99

    if ($PSCmdlet.ShouldProcess("Flag Type '$Name'", "Create")) {
        $resp = Invoke-HuduRequest -Method POST -Resource "/api/v1/flag_types" -Body $body
        return ($resp.flag_type ?? $resp)
    }
}
