function Get-HuduFeatureAvailability {
    <#
    .SYNOPSIS
    Safely Determine if a Core Hudu Feature is Available

    .DESCRIPTION
    Uses Hudu API to query core objects to determine their accessibility.
    #>
    Param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('corefeature')]
        [ValidateScript({Assert-AllowedObjectType -InputType $_ -AllowedCanonicals @(
                "VlanZone", "Vlan", "Procedure", "Website", "RackStorage", "Network", "IpAddress", "Article", "Company", "Asset", "AssetPassword"
        )})][String]$Core_Feature
    )

    $ObjectType = "$(Get-ObjectTypeFromCononical -inputData $Core_Feature)"
    $Resource = switch ($ObjectType) {
        "VlanZone"      { "/api/v1/vlan_zones" }
        "Vlan"          { "/api/v1/vlans" }
        "Procedure"     { "/api/v1/procedures" }
        "Website"       { "/api/v1/websites" }
        "RackStorage"   { "/api/v1/rack_storages" }
        "Network"       { "/api/v1/networks" }
        "IpAddress"     { "/api/v1/ip_addresses" }
        "Article"       { "/api/v1/articles" }
        "Company"       { "/api/v1/companies" }
        "Asset"         { "/api/v1/assets" }
        "AssetPassword" { "/api/v1/asset_passwords" }
        default          { throw "Unsupported core feature: $Core_Feature" }
    }

    try {
        $Result = Invoke-HuduFeatureAvailabilityProbe -Resource $Resource
        return -not (Test-HuduFeatureDisabledMessage -InputObject $Result)
    } catch {
        if (Test-HuduFeatureDisabledMessage -InputObject $_) {
            return $false
        }

        throw
    }
}

function Invoke-HuduFeatureAvailabilityProbe {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Resource
    )

    $HuduAPIKey = Get-HuduApiKey
    $HuduBaseURL = Get-HuduBaseURL

    $ParamCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    $ParamCollection.Add('page', '1')
    $ParamCollection.Add('page_size', '1')

    $UriBuilder = [System.UriBuilder]('{0}{1}' -f $HuduBaseURL, $Resource)
    $UriBuilder.Query = $ParamCollection.ToString()

    $Headers = @{
        'x-api-key' = (New-Object PSCredential 'user', $HuduAPIKey).GetNetworkCredential().Password
    }

    if (($Script:Int_HuduCustomHeaders | Measure-Object).count -gt 0) {
        foreach ($Entry in $Int_HuduCustomHeaders.GetEnumerator()) {
            $Headers[$Entry.Name] = $Entry.Value
        }
    }

    Invoke-RestMethod -Method GET -Uri $UriBuilder.Uri -Headers $Headers -ContentType 'application/json; charset=utf-8' -ErrorAction Stop
}

function Test-HuduFeatureDisabledMessage {
    [CmdletBinding()]
    Param (
        [AllowNull()]
        [object]$InputObject
    )

    $Details = Get-HuduFeatureAvailabilityDetails -InputObject $InputObject
    return ($Details -ilike '*disabled for this instance*')
}

function Get-HuduFeatureAvailabilityDetails {
    [CmdletBinding()]
    Param (
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return ''
    }

    $Parts = [System.Collections.Generic.List[string]]::new()

    if ($InputObject -is [System.Management.Automation.ErrorRecord]) {
        Add-HuduFeatureAvailabilityDetail -Parts $Parts -Value $InputObject.Exception.Message
        Add-HuduFeatureAvailabilityDetail -Parts $Parts -Value $InputObject.ErrorDetails
        Add-HuduFeatureAvailabilityDetail -Parts $Parts -Value $InputObject.ErrorDetails.Message
        Add-HuduFeatureAvailabilityDetail -Parts $Parts -Value $InputObject.Exception.Response
        Add-HuduFeatureAvailabilityDetail -Parts $Parts -Value (Get-HuduFeatureAvailabilityResponseBody -Response $InputObject.Exception.Response)
    } else {
        Add-HuduFeatureAvailabilityDetail -Parts $Parts -Value $InputObject
    }

    return ($Parts -join "`n")
}

function Add-HuduFeatureAvailabilityDetail {
    Param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Parts,

        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [string]) {
        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            $Parts.Add($Value)
        }
        return
    }

    try {
        $Json = $Value | ConvertTo-Json -Depth 20 -Compress -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($Json)) {
            $Parts.Add($Json)
        }
    } catch {
        $StringValue = $Value.ToString()
        if (-not [string]::IsNullOrWhiteSpace($StringValue)) {
            $Parts.Add($StringValue)
        }
    }
}

function Get-HuduFeatureAvailabilityResponseBody {
    Param (
        [AllowNull()]
        [object]$Response
    )

    if ($null -eq $Response) {
        return $null
    }

    try {
        if ($Response.Content -and ($Response.Content | Get-Member -Name ReadAsStringAsync -MemberType Method)) {
            return $Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    } catch {
        return $null
    }

    try {
        if ($Response.GetType().GetMethod('GetResponseStream')) {
            $Stream = $Response.GetResponseStream()
            if ($null -eq $Stream) {
                return $null
            }

            $Reader = [System.IO.StreamReader]::new($Stream)
            try {
                return $Reader.ReadToEnd()
            } finally {
                $Reader.Dispose()
            }
        }
    } catch {
        return $null
    }

    return $null
}
