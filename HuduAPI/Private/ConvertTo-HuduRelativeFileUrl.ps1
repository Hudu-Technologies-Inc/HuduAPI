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
        $wrapperPropertyNames = @('public_photo', 'public_photos', 'upload', 'uploads')

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

        function Convert-HuduUrlProperty {
            param([AllowNull()][object]$Object)

            if ($null -eq $Object -or $Object -is [string]) {
                return $Object
            }

            if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string] -and $Object -isnot [pscustomobject] -and $Object -isnot [System.Collections.IDictionary]) {
                foreach ($item in @($Object)) {
                    Convert-HuduUrlProperty -Object $item | Out-Null
                }
                return $Object
            }

            if ($Object -is [System.Collections.IDictionary]) {
                if ($Object.Contains('url') -and $Object['url'] -is [string]) {
                    $Object['url'] = Convert-HuduFileUrlString -Url $Object['url']
                }

                foreach ($wrapperPropertyName in $wrapperPropertyNames) {
                    if ($Object.Contains($wrapperPropertyName)) {
                        Convert-HuduUrlProperty -Object $Object[$wrapperPropertyName] | Out-Null
                    }
                }

                return $Object
            }

            $urlProperty = $Object.PSObject.Properties['url']
            if ($urlProperty -and $urlProperty.IsSettable -and $urlProperty.Value -is [string]) {
                $urlProperty.Value = Convert-HuduFileUrlString -Url $urlProperty.Value
            }

            foreach ($wrapperPropertyName in $wrapperPropertyNames) {
                $wrapperProperty = $Object.PSObject.Properties[$wrapperPropertyName]
                if ($wrapperProperty) {
                    Convert-HuduUrlProperty -Object $wrapperProperty.Value | Out-Null
                }
            }

            return $Object
        }
    }

    process {
        Convert-HuduUrlProperty -Object $InputObject
    }
}
