function Write-APIErrorObjectToFile {
    param (
        [Parameter(Mandatory)]
        [object]$ErrorObject,

        [Parameter()]
        [string]$Name = "Unnamed"
    )

    $stringOutput = try {
        $ErrorObject | Format-List -Force | Out-String
    } catch {
        "Failed to stringify object: $_"
    }

    $propertyDump = try {
        $props = $ErrorObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
        $lines = foreach ($p in $props) {
            try {
                "$p = $($ErrorObject.$p)"
            } catch {
                "$p = <unreadable>"
            }
        }
        $lines -join "`n"
    } catch {
        "Failed to enumerate properties: $_"
    }

    $logContent = @"
==== OBJECT STRING ====
$stringOutput

==== PROPERTY DUMP ====
$propertyDump
"@

    if ($global:HAPI_ERRORS_DIRECTORY -and (Test-Path $global:HAPI_ERRORS_DIRECTORY)) {
        $filename = "$($Name.Trim())_error_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $fullPath = Join-Path $global:HAPI_ERRORS_DIRECTORY $filename
        Set-Content -Path $fullPath -Value $logContent -Encoding UTF8
        Write-Host "Error written to $fullPath" -ForegroundColor Yellow
    }

    Write-Host "$logContent" -ForegroundColor Yellow
}


function Invoke-HuduRequest {
    <#
    .SYNOPSIS
    Main Hudu API function

    .DESCRIPTION
    Calls Hudu API with token

    .PARAMETER Method
    GET,POST,DELETE,PUT,etc

    .PARAMETER Path
    Path to API endpoint

    .PARAMETER Params
    Hashtable of parameters

    .PARAMETER Body
    JSON encoded body string

    .PARAMETER Form
    Multipart form data

    .EXAMPLE
    Invoke-HuduRequest -Resource '/api/v1/articles' -Method GET
    #>
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]$Method = 'GET',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Resource,

        [Parameter()]
        [hashtable]$Params = @{},

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [hashtable]$Form
    )

    $HuduAPIKey = Get-HuduApiKey
    $HuduBaseURL = Get-HuduBaseURL

    # Assemble parameters
    $ParamCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)

    # Sort parameters
    foreach ($Item in ($Params.GetEnumerator() | Sort-Object -CaseSensitive -Property Key)) {
        $ParamCollection.Add($Item.Key, $Item.Value)
    }

    # Query string
    $Request = $ParamCollection.ToString()

    $Headers = @{
        'x-api-key' = (New-Object PSCredential 'user', $HuduAPIKey).GetNetworkCredential().Password;
    }

    if (($Script:Int_HuduCustomHeaders | Measure-Object).count -gt 0){
        
        foreach($Entry in $Int_HuduCustomHeaders.GetEnumerator()) {
            $Headers[$Entry.Name] = $Entry.Value
        }
    }

    $ContentType = 'application/json; charset=utf-8'

    $Uri = '{0}{1}' -f $HuduBaseURL, $Resource
    # Make API call URI
    if ($Request) {
        $UriBuilder = [System.UriBuilder]$Uri
        $UriBuilder.Query = $Request
        $Uri = $UriBuilder.Uri
    }
    Write-Verbose ( '{0} [{1}]' -f $Method, $Uri )

    $RestMethod = @{
        Method      = $Method
        Uri         = $Uri
        Headers     = $Headers
        ContentType = $ContentType
    }

    if ($Body) {
        $RestMethod.Body = $Body
        Write-Verbose $Body
    }

    if ($Form) {
        $RestMethod.Form = $Form
        Write-Verbose ( $Form | Out-String )
    }

    try {
        $Results = Invoke-RestMethod @RestMethod
    } catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -like '*Retry later*' -or $errorMessage -like '*429*Too Many Requests*') {
            $now = Get-Date
            $windowLength = 5 * 60  # 5 minutes in seconds
            $secondsIntoWindow = (($now.Minute % 5) * 60) + $now.Second
            $secondsUntilNextWindow = [math]::Max(0, $windowLength - $secondsIntoWindow)

            $jitter = Get-Random -Minimum 1 -Maximum 5
            $totalSleep = [math]::Max(0, $secondsUntilNextWindow + $jitter)
            Write-Host "Hudu API Rate limited; Sleeping for $totalSleep seconds to wait for next rate limit window..."
            Start-Sleep -Seconds $totalSleep
        } else {
            Write-APIErrorObjectToFile -name "$path-$method" -ErrorObject @{
                exception = $_
                request = $RestMethod
                resolution = "Trying again in 5 seconds."
            }
            Start-Sleep -Seconds 5
        }

        try {
            $Results = Invoke-RestMethod @RestMethod
        } catch {
            Write-APIErrorObjectToFile -name "$resource-$method-retry" -ErrorObject @{
                exception = $_
                request = $RestMethod
                resolution = "Retry failed as well. Handle this error here or avoid it prior."
            }
            return $null
        }
    }

    $Results
}
