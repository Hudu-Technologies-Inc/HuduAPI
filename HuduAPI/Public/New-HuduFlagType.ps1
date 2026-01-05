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
        [ValidateSet('red', 'crimson', 'scarlet', 'rot', 'karminrot', 'scharlachrot', 'rouge', 'cramoisi', 'écarlate', 'rosso', 'cremisi', 'scarlatto', 'rojo', 'carmesí', 'escarlata', 'blue', 'navy', 'blau', 'marineblau', 'bleu', 'bleu marine', 'blu', 'blu navy', 'azul', 'azul marino', 'green', 'lime', 'grün', 'limettengrün', 'vert', 'vert citron', 'verde', 'verde lime', 'verde', 'verde lima', 'yellow', 'gold', 'gelb', 'gold', 'jaune', 'or', 'giallo', 'oro', 'amarillo', 'oro', 'purple', 'violet', 'lila', 'violett', 'violet', 'pourpre', 'viola', 'porpora', 'púrpura', 'violeta', 'orange', 'orange', 'orange', 'arancione', 'naranja', 'light pink', 'pink', 'baby pink', 'hellrosa', 'rosa', 'rose clair', 'rose', 'rosa chiaro', 'rosa', 'rosa claro', 'rosa', 'light blue', 'baby blue', 'sky blue', 'hellblau', 'babyblau', 'himmelblau', 'bleu clair', 'bleu ciel', 'azzurro', 'blu chiaro', 'azul claro', 'celeste', 'light green', 'mint', 'hellgrün', 'mintgrün', 'vert clair', 'menthe', 'verde chiaro', 'menta', 'verde claro', 'menta', 'light purple', 'lavender', 'helllila', 'lavendel', 'violet clair', 'lavande', 'viola chiaro', 'lavanda', 'morado claro', 'lavanda', 'light orange', 'peach', 'hellorange', 'pfirsich', 'orange clair', 'pêche', 'arancione chiaro', 'pesca', 'naranja claro', 'melocotón', 'light yellow', 'cream', 'hellgelb', 'creme', 'jaune clair', 'crème', 'giallo chiaro', 'crema', 'amarillo claro', 'crema', 'white', 'weiß', 'blanc', 'bianco', 'blanco', 'grey', 'gray', 'silver', 'grau', 'silber', 'gris', 'argent', 'grigio', 'argento', 'gris', 'plateado',IgnoreCase = $true)]
        [string]$Color
    )
    $bodyObj = @{
        flag_type = @{
            name  = $Name
            color = $(Set-ColorFromCanonical -inputData $Color)
        }
    }

    $body = $bodyObj | ConvertTo-Json -Depth 99

    if ($PSCmdlet.ShouldProcess("Flag Type '$Name'", "Create")) {
        $resp = Invoke-HuduRequest -Method POST -Resource "/api/v1/flag_types" -Body $body
        return ($resp.flag_type ?? $resp)
    }
}
