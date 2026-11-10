# Offline request-contract tests; no Hudu instance or credentials are required.
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../HuduAPI.psd1') -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module HuduAPI -Force -ErrorAction SilentlyContinue
}

Describe 'Set-HuduAsset custom field payloads' {
    BeforeEach {
        Mock Get-HuduAssets -ModuleName HuduAPI {
            [pscustomobject]@{
                id = 42
                name = 'Existing asset'
                company_id = 7
                asset_layout_id = 12
                fields = @(
                    [pscustomobject]@{label='Score';value='1001'}
                    [pscustomobject]@{label='Instructions';value='Static layout text'}
                )
            }
        }
        Mock Invoke-HuduRequest -ModuleName HuduAPI {
            param($Method, $Resource, $Body)
            [pscustomobject]@{
                Method = $Method
                Resource = $Resource
                Payload = $Body | ConvertFrom-Json -AsHashtable
            }
        }
    }

    It 'preserves existing fields during a rename when Fields is omitted' {
        $result = Set-HuduAsset -Id 42 -Name 'Renamed' -Confirm:$false
        $result.Method | Should -Be 'put'
        $result.Resource | Should -Be '/api/v1/companies/7/assets/42'
        $result.Payload.asset.name | Should -BeExactly 'Renamed'
        $result.Payload.asset.custom_fields.Count | Should -Be 2
        $result.Payload.asset.custom_fields[0].score | Should -BeExactly '1001'
        $result.Payload.asset.custom_fields[1].instructions | Should -BeExactly 'Static layout text'
    }

    It 'serializes an explicit empty array without rebuilding existing field values' {
        $result = Set-HuduAsset -Id 42 -Name 'Renamed' -Fields @() -Confirm:$false
        $result.Payload.asset.ContainsKey('custom_fields') | Should -BeTrue
        ($result.Payload.asset.custom_fields -is [array]) | Should -BeTrue
        $result.Payload.asset.custom_fields.Count | Should -Be 0
        $result.Payload.asset.name | Should -BeExactly 'Renamed'
        Should -Invoke Invoke-HuduRequest -ModuleName HuduAPI -Times 1 -Exactly
    }

    It 'honors an empty array supplied through splatting' {
        $parameters = @{Id=42;Fields=@();Confirm=$false}
        $result = Set-HuduAsset @parameters
        $result.Payload.asset.custom_fields.Count | Should -Be 0
    }

    It 'serializes an explicitly bound null without using existing values' {
        $result = Set-HuduAsset -Id 42 -Fields $null -Confirm:$false
        $result.Payload.asset.ContainsKey('custom_fields') | Should -BeTrue
        $null -eq $result.Payload.asset.custom_fields | Should -BeTrue
    }

    It 'sends supplied zero and precise decimal strings without adding existing fields' {
        $fraction = '0.123456789012345678901234567890123456789'
        $result = Set-HuduAsset -Id 42 -Fields @(@{Score='0'}, @{Fraction=$fraction}) -Confirm:$false
        $result.Payload.asset.custom_fields.Count | Should -Be 2
        $result.Payload.asset.custom_fields[0].Score | Should -BeExactly '0'
        $result.Payload.asset.custom_fields[1].Fraction | Should -BeExactly $fraction
    }

    It 'does not send an empty-field update with WhatIf' {
        Set-HuduAsset -Id 42 -Fields @() -WhatIf
        Should -Invoke Invoke-HuduRequest -ModuleName HuduAPI -Times 0 -Exactly
    }
}
