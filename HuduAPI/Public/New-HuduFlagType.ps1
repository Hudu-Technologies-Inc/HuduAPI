function New-HuduFlagType {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'LightPink', 'LightBlue', 'LightGreen', 'LightPurple', 'LightOrange', 'LightYellow', 'White', 'Grey')]
        [string]$Color
    )

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
