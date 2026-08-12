function ConvertTo-HuduRelativeFileUrl {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject
    )

    begin {
        $baseUrl = (Get-HuduBaseURL).TrimEnd('/')
        $escapedBaseUrl = [regex]::Escape($baseUrl)

        function Convert-HuduFileUrlString {
            param([string]$Url)

            if ([string]::IsNullOrWhiteSpace($Url) -or $Url.StartsWith('/')) {
                return $Url
            }

            if ($Url -match "^(?i)$escapedBaseUrl(?<Path>/(?:public_photo[s]?|file|files|uploads?)/.*)$") {
                return $Matches.Path
            }

            return $Url
        }

        function Convert-HuduFileUrlObject {
            param([AllowNull()][object]$Object)

            if ($null -eq $Object) {
                return $null
            }

            if ($Object -is [string]) {
                return Convert-HuduFileUrlString -Url $Object
            }

            if ($Object -is [System.Collections.IDictionary]) {
                foreach ($key in @($Object.Keys)) {
                    $Object[$key] = Convert-HuduFileUrlObject -Object $Object[$key]
                }
                return $Object
            }

            if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string] -and $Object -isnot [pscustomobject]) {
                foreach ($item in @($Object)) {
                    Convert-HuduFileUrlObject -Object $item | Out-Null
                }
                return $Object
            }

            foreach ($property in @($Object.PSObject.Properties)) {
                if (-not $property.IsSettable) {
                    continue
                }

                if ($property.Value -is [string]) {
                    $property.Value = Convert-HuduFileUrlString -Url $property.Value
                } elseif ($null -ne $property.Value) {
                    Convert-HuduFileUrlObject -Object $property.Value | Out-Null
                }
            }

            return $Object
        }
    }

    process {
        Convert-HuduFileUrlObject -Object $InputObject
    }
}
