BeforeAll {
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    foreach ($file in @(
        'Private\Invoke-HuduRequest.ps1'
        'Private\Write-ErrorObject.ps1'
        'Public\Get-HuduAPIKey.ps1'
        'Public\Get-HuduBaseURL.ps1'
        'Public\Get-HuduAssets.ps1'
        'Public\New-HuduCustomHeaders.ps1'
        'Public\Remove-HuduCustomHeaders.ps1'
        'Public\Set-HuduAsset.ps1'
        'Public\Set-HuduRequestOption.ps1'
        'Public\Set-HapiErrorsDirectory.ps1'
    )) {
        . (Join-Path $moduleRoot $file)
    }
}

Describe 'Request session headers' {
    BeforeEach {
        $script:Int_HuduWebSession = $null
        $script:Int_HuduCustomHeaders = $null
        $script:testBaseURL = 'https://first.example'
        $script:requests = @()
        Mock Get-HuduApiKey { ConvertTo-SecureString 'test-api-key' -AsPlainText -Force }
        Mock Get-HuduBaseURL { $script:testBaseURL }
        Mock Invoke-RestMethod {
            param($Headers, $WebSession, $Uri)
            $WebSession.Headers.Count | Should -Be 0
            foreach ($key in $Headers.Keys) {
                $WebSession.Headers[$key] = $Headers[$key]
            }
            $script:requests += @{
                Session = $WebSession
                Headers = $Headers.Clone()
                Uri = [string]$Uri
            }
            @{ success = $true }
        }
    }

    It 'removes old custom headers when replacing them and reuses the session' {
        New-HuduCustomHeaders -Headers @{
            'CF-Access-Client-Id' = 'old-client'
            'CF-Access-Client-Secret' = 'old-secret'
        }
        Invoke-HuduRequest -Resource '/api/v1/assets' | Out-Null
        New-HuduCustomHeaders -Headers @{ 'CF-Access-Client-Id' = 'new-client' }
        Invoke-HuduRequest -Resource '/api/v1/assets' | Out-Null

        [object]::ReferenceEquals($script:requests[0].Session, $script:requests[1].Session) | Should -BeTrue
        $script:requests[1].Headers['CF-Access-Client-Id'] | Should -Be 'new-client'
        $script:requests[1].Headers.ContainsKey('CF-Access-Client-Secret') | Should -BeFalse
        $script:requests[1].Session.Headers.ContainsKey('CF-Access-Client-Secret') | Should -BeFalse
        $script:requests[1].Headers['x-api-key'] | Should -Be 'test-api-key'
    }

    It 'does not forward removed custom headers after changing the base URL' {
        New-HuduCustomHeaders -Headers @{ 'CF-Access-Client-Secret' = 'old-secret' }
        Invoke-HuduRequest -Resource '/api/v1/assets' | Out-Null
        Remove-HuduCustomHeaders -Confirm:$false
        $script:testBaseURL = 'https://second.example'
        Invoke-HuduRequest -Resource '/api/v1/assets' | Out-Null

        [object]::ReferenceEquals($script:requests[0].Session, $script:requests[1].Session) | Should -BeTrue
        $script:requests[1].Uri | Should -Be 'https://second.example/api/v1/assets'
        $script:requests[1].Headers.Count | Should -Be 1
        $script:requests[1].Session.Headers.ContainsKey('CF-Access-Client-Secret') | Should -BeFalse
    }
}

Describe 'Existing asset identity' {
    BeforeEach {
        $script:asset = [pscustomobject]@{
            id = 42
            company_id = 7
            name = 'Original'
            asset_layout_id = 3
            fields = @([pscustomobject]@{ label = 'Test Field'; value = 'original-value' })
        }
        Mock Get-HuduAssets { $script:asset }
        Mock Invoke-HuduRequest { param($Body) $Body | ConvertFrom-Json }
    }

    It 'rejects a mismatched asset before fetching or updating anything' {
        { Set-HuduAsset -Id 43 -ExistingAsset $script:asset -Confirm:$false } |
            Should -Throw '*ExistingAsset.id must match*'
        Should -Invoke Get-HuduAssets -Times 0 -Exactly
        Should -Invoke Invoke-HuduRequest -Times 0 -Exactly
    }

    It 'rejects an asset without an ID before updating anything' {
        { Set-HuduAsset -Id 42 -ExistingAsset ([pscustomobject]@{ name = 'No ID' }) -Confirm:$false } |
            Should -Throw '*ExistingAsset.id must match*'
        Should -Invoke Invoke-HuduRequest -Times 0 -Exactly
    }

    It 'uses a matching supplied asset without fetching it again' {
        $result = Set-HuduAsset -Id 42 -ExistingAsset $script:asset -Name 'Updated' -Confirm:$false
        $result.asset.id | Should -Be 42
        $result.asset.name | Should -Be 'Updated'
        $result.asset.custom_fields.test_field | Should -Be 'original-value'
        Should -Invoke Get-HuduAssets -Times 0 -Exactly
        Should -Invoke Invoke-HuduRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'put' -and $Resource -eq '/api/v1/companies/7/assets/42'
        }
    }

    It 'still fetches the asset when ExistingAsset is omitted' {
        $script:asset.company_id = 9
        $script:asset.asset_layout_id = 8
        $result = Set-HuduAsset -Id 42 -Name 'Updated' -Confirm:$false
        $result.asset.id | Should -Be 42
        $result.asset.company_id | Should -Be 9
        $result.asset.asset_layout_id | Should -Be 8
        Should -Invoke Get-HuduAssets -Times 1 -Exactly -ParameterFilter { $Id -eq 42 }
        Should -Invoke Invoke-HuduRequest -Times 1 -Exactly -ParameterFilter { $Resource -eq '/api/v1/companies/9/assets/42' }
    }

    It 'produces the same payload from a fresh ExistingAsset while avoiding only the GET' {
        $normal = Set-HuduAsset -Id 42 -Name 'Updated' -Confirm:$false
        $cached = Set-HuduAsset -Id 42 -Name 'Updated' -ExistingAsset $script:asset -Confirm:$false
        ($normal | ConvertTo-Json -Depth 10 -Compress) | Should -Be ($cached | ConvertTo-Json -Depth 10 -Compress)
        Should -Invoke Get-HuduAssets -Times 1 -Exactly
    }
}

Describe 'Legacy retries and optional diagnostics' {
    BeforeEach {
        $script:logDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:logDirectory | Out-Null
        $script:Int_HuduWebSession = $null
        $script:Int_HuduCustomHeaders = $null
        $script:HAPI_ERRORS_DIRECTORY = $null
        $script:HAPI_ERROR_COLOR = $null
        $script:SKIP_HAPI_ERROR_RETRY = $false
        $script:SKIP_HAPI_POST_RETRY = $false
        $script:HAPI_RETRY_DELAY_SECONDS = 0
        $script:HAPI_RATE_LIMIT_WINDOW_SECONDS = $null
        Mock Get-HuduApiKey { ConvertTo-SecureString 'test-api-key' -AsPlainText -Force }
        Mock Get-HuduBaseURL { 'https://test.example' }
        Mock Invoke-RestMethod { throw 'Simulated server failure' }
        Mock Start-Sleep {}
        Mock Write-Host {}
    }

    It 'returns null quietly when <Option> skips retries, even with ErrorAction Stop' -ForEach @(
        @{ Option = 'SkipPostRetry' }
        @{ Option = 'SkipRetry' }
    ) {
        if ($Option -eq 'SkipPostRetry') {
            Set-HuduRequestOption -SkipPostRetry $true | Out-Null
            Set-HapiErrorsDirectory -Path $script:logDirectory | Out-Null
        } else {
            Set-HapiErrorsDirectory -Path $script:logDirectory -skipRetry $true | Out-Null
        }
        @(Invoke-HuduRequest -Method POST -Resource '/api/v1/assets' -Body '{"secret":"body-secret"}' -ErrorAction Stop 2>&1 3>&1) |
            Should -BeNullOrEmpty
        @(Get-ChildItem $script:logDirectory -Filter '*.log').Count | Should -Be 0
        Should -Invoke Write-Host -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'keeps disk and host logging opt-in when POST retries are skipped' {
        Set-HuduRequestOption -SkipPostRetry $true | Out-Null
        Invoke-HuduRequest -Method POST -Resource '/api/v1/assets' -ErrorAction SilentlyContinue
        @(Get-ChildItem $script:logDirectory -Filter '*.log').Count | Should -Be 0
        Should -Invoke Write-Host -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'returns null after exhausted retries under ErrorAction Stop and logs only when configured' {
        Set-HapiErrorsDirectory -Path $script:logDirectory | Out-Null
        @(Invoke-HuduRequest -Method POST -Resource '/api/v1/assets' -Body '{"secret":"body-secret"}' -ErrorAction Stop 2>&1) |
            Should -BeNullOrEmpty
        $logs = @(Get-ChildItem $script:logDirectory -Filter '*.log')
        $logs.Count | Should -Be 2
        ($logs | Get-Content -Raw | Out-String) | Should -Not -Match 'test-api-key|body-secret'
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly
    }

    It 'keeps failure diagnostics optional without configuring a log directory' {
        Invoke-HuduRequest -Resource '/api/v1/assets' -ErrorAction Stop | Should -BeNullOrEmpty
        @(Get-ChildItem $script:logDirectory -Filter '*.log').Count | Should -Be 0
        Should -Invoke Write-Host -Times 0 -Exactly
    }

    It 'still retries a failed POST by default' {
        $script:HAPI_RETRY_DELAY_SECONDS = $null
        Invoke-HuduRequest -Method POST -Resource '/api/v1/assets' -ErrorAction SilentlyContinue
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 5 }
    }

    It 'retains rate-limit timing for <Scenario>' -ForEach @(
        @{ Scenario = 'the default five-minute window'; Window = 300; At = '2026-11-17T12:04:58'; Expected = 4 }
        @{ Scenario = 'an explicitly configured window'; Window = 17; At = '2026-11-17T00:00:35'; Expected = 18 }
    ) {
        if ($Window -ne 300) { Set-HuduRequestOption -RateLimitWindowSeconds $Window | Out-Null }
        $script:clock = [datetime]$At
        Mock Get-Date { $script:clock }
        Mock Get-Random { 2 }
        Mock Invoke-RestMethod { throw '429 (Too Many Requests)' }
        Invoke-HuduRequest -Resource '/api/v1/assets' -ErrorAction Stop | Should -BeNullOrEmpty
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq $Expected }
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly
    }
}
