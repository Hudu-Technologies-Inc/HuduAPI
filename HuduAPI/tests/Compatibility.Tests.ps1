param([string]$ModulePath = (Join-Path $PSScriptRoot '../HuduAPI.psd1'))

BeforeAll {
    if (-not ('HuduAPI.Tests.LoopbackServer' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'fixtures/LoopbackServer.cs') -ErrorAction Stop
    }
    $script:moduleUnderTest = (Resolve-Path -LiteralPath $ModulePath).Path
    Import-Module $script:moduleUnderTest -Force -ErrorAction Stop
}
AfterAll { Remove-Module HuduAPI -Force -ErrorAction SilentlyContinue }

Describe 'Existing request contracts over real HTTP' -Tag Offline {
    BeforeEach {
        $script:server = [HuduAPI.Tests.LoopbackServer]::new()
        $script:otherServer = $null
        $script:logs = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:logs | Out-Null
        & (Get-Module HuduAPI) {
            param($url, $logs)
            $script:Int_HuduWebSession = $null
            $script:Int_HuduCustomHeaders = $null
            $script:Int_HuduBaseURL = $url
            $script:Int_HuduAPIKey = ConvertTo-SecureString 'key-A' -AsPlainText -Force
            $script:SKIP_HAPI_ERROR_RETRY = $false
            $script:SKIP_HAPI_POST_RETRY = $false
            $script:HAPI_RETRY_DELAY_SECONDS = 0
            $script:HAPI_RATE_LIMIT_WINDOW_SECONDS = $null
            $script:HAPI_ERRORS_DIRECTORY = $logs
        } $script:server.BaseUrl $script:logs
        Mock Start-Sleep -ModuleName HuduAPI {}
        Mock Write-Host -ModuleName HuduAPI {}
    }
    AfterEach {
        $script:server.Dispose()
        if ($script:otherServer) { $script:otherServer.Dispose() }
    }

    It 'preserves query encoding and API authentication' {
        $result = Invoke-HuduRequest -Resource '/api/v1/assets' -Params @{ search = 'a+b & café/雪'; page = 2; archived = 'false' } -ErrorAction Stop
        $query = [Web.HttpUtility]::ParseQueryString($result.query)
        $query['search'] | Should -Be 'a+b & café/雪'
        $query['page'] | Should -Be '2'
        $query['archived'] | Should -Be 'false'
        $result.headers.'x-api-key' | Should -Be 'key-A'
    }

    It 'preserves <Method> JSON request bytes' -ForEach @(
        @{ Method = 'POST' }; @{ Method = 'PUT' }; @{ Method = 'PATCH' }; @{ Method = 'DELETE' }
    ) {
        Invoke-HuduRequest -Resource '/warmup' | Out-Null
        $body = '{"name":"café 雪","enabled":false,"count":0,"notes":null}'
        $result = Invoke-HuduRequest -Method $Method -Resource '/api/v1/assets/42' -Body $body -ErrorAction Stop
        $result.method | Should -Be $Method
        $result.body | Should -Be $body
        $result.headers.'Content-Type' | Should -Be 'application/json; charset=utf-8'
    }

    It 'discards response cookies between calls' {
        $script:server.Enqueue(200, $null, 'session=old; Path=/; HttpOnly')
        $first = Invoke-HuduRequest -Resource '/first' -ErrorAction Stop
        $second = Invoke-HuduRequest -Resource '/second' -ErrorAction Stop
        $second.headers.PSObject.Properties.Name | Should -Not -Contain 'Cookie'
    }

    It 'preserves TCP connection reuse even when the server sets cookies' -Tag Performance -Skip:($PSVersionTable.PSVersion -lt [version]'7.4') {
        $script:server.Enqueue(200, $null, 'session=old; Path=/')
        $first = Invoke-HuduRequest -Resource '/first' -ErrorAction Stop
        $second = Invoke-HuduRequest -Resource '/second' -ErrorAction Stop
        $second.clientPort | Should -Be $first.clientPort
    }

    It 'discards cookies whose paths do not match the next request' {
        $script:server.Enqueue(200, $null, 'session=hidden; Path=/hidden')
        Invoke-HuduRequest -Resource '/first' | Out-Null
        Invoke-HuduRequest -Resource '/elsewhere' | Out-Null
        $result = Invoke-HuduRequest -Resource '/hidden/final' -ErrorAction Stop
        $result.headers.PSObject.Properties.Name | Should -Not -Contain 'Cookie'
    }

    It 'discards response cookies before a retry of HTTP <Status>' -ForEach @(@{ Status = 500 }; @{ Status = 429 }) {
        $script:server.Enqueue($Status, '{"error":"temporary failure"}', 'session=failed; Path=/')
        $result = Invoke-HuduRequest -Resource '/retry' -ErrorAction Stop
        $result.headers.PSObject.Properties.Name | Should -Not -Contain 'Cookie'
        $script:server.Requests.Count | Should -Be 2
        Should -Invoke Start-Sleep -ModuleName HuduAPI -Times 1 -Exactly
    }

    It 'retains normal cookie behavior inside one redirect chain' {
        $script:server.Enqueue(302, $null, 'session=redirect; Path=/', $false, ($script:server.BaseUrl + '/final'))
        (Invoke-HuduRequest -Resource '/redirect' -ErrorAction Stop).headers.Cookie | Should -Be 'session=redirect'
        (Invoke-HuduRequest -Resource '/next' -ErrorAction Stop).headers.PSObject.Properties.Name | Should -Not -Contain 'Cookie'
    }

    It 'clears cookies when rotating credentials through the public API' {
        $script:server.Enqueue(200, $null, 'session=identity-A; Path=/')
        Invoke-HuduRequest -Resource '/first' | Out-Null
        $script:server.Enqueue(200, '{"version":"2.46.0"}')
        New-HuduAPIKey 'key-B'
        $result = Invoke-HuduRequest -Resource '/second' -ErrorAction Stop
        $result.headers.'x-api-key' | Should -Be 'key-B'
        $result.headers.PSObject.Properties.Name | Should -Not -Contain 'Cookie'
        $script:server.Requests[1].Headers.ContainsKey('Cookie') | Should -BeFalse
    }

    It 'keeps cookies and credentials isolated after a base-URL change on the same hostname' {
        $script:server.Enqueue(200, $null, 'session=instance-A; Path=/')
        Invoke-HuduRequest -Resource '/first' | Out-Null
        $script:otherServer = [HuduAPI.Tests.LoopbackServer]::new()
        # Public URL setup enforces HTTPS; change only the URL for this loopback HTTP fixture.
        & (Get-Module HuduAPI) { param($url) $script:Int_HuduBaseURL = $url } $script:otherServer.BaseUrl
        $script:otherServer.Enqueue(200, '{"version":"2.46.0"}')
        New-HuduAPIKey 'key-B'
        $result = Invoke-HuduRequest -Resource '/second' -ErrorAction Stop
        $result.headers.'x-api-key' | Should -Be 'key-B'
        $result.headers.PSObject.Properties.Name | Should -Not -Contain 'Cookie'
        $script:otherServer.Requests.Count | Should -Be 2
        $script:server.Requests.Count | Should -Be 1
    }

    It 'removes a custom <Header> value on subsequent requests' -ForEach @(
        @{ Header = 'User-Agent'; Value = 'migration-agent'; DefaultPattern = 'PowerShell' }
        @{ Header = 'CF-Access-Client-Secret'; Value = 'synthetic-secret'; DefaultPattern = $null }
        @{ Header = 'Authorization'; Value = 'Bearer synthetic'; DefaultPattern = $null }
        @{ Header = 'Cookie'; Value = 'explicit=synthetic'; DefaultPattern = $null }
        @{ Header = 'Content-Language'; Value = 'fr'; DefaultPattern = $null }
    ) {
        New-HuduCustomHeaders -Headers @{ $Header = $Value }
        (Invoke-HuduRequest -Resource '/first').headers.$Header | Should -Be $Value
        Remove-HuduCustomHeaders -Confirm:$false
        $result = Invoke-HuduRequest -Resource '/second' -ErrorAction Stop
        if ($DefaultPattern) { $result.headers.$Header | Should -Match $DefaultPattern }
        else { $result.headers.PSObject.Properties.Name | Should -Not -Contain $Header }
    }

    It 'preserves pagination boundaries and result ordering' {
        $script:server.Enqueue(200, '{"companies":[{"id":1},{"id":2}]}')
        $script:server.Enqueue(200, '{"companies":[]}')
        $result = @(& (Get-Module HuduAPI) {
            Invoke-HuduRequestPaginated -HuduRequest @{ Resource = '/api/v1/companies'; Params = @{} } -Property companies -PageSize 2
        })
        $result.id | Should -Be @(1,2)
        $script:server.Requests[0].Query | Should -Be '?page=1&page_size=2'
        $script:server.Requests[1].Query | Should -Be '?page=2&page_size=2'
    }

    It 'retries multipart uploads and then handles JSON normally' {
        $file = Join-Path $TestDrive 'attachment.txt'
        [IO.File]::WriteAllText($file, 'attachment café 雪', [Text.UTF8Encoding]::new($false))
        $script:server.Enqueue(500, '{"error":"temporary failure"}')
        $result = New-HuduUpload -FilePath $file -RecordId 42 -RecordType Asset -Confirm:$false -ErrorAction Stop
        $result.headers.'Content-Type' | Should -Match '^multipart/form-data; boundary='
        foreach ($request in $script:server.Requests) { $request.Body | Should -Match 'attachment café 雪' }
        $json = Invoke-HuduRequest -Method PUT -Resource '/json' -Body '{"ok":true}' -ErrorAction Stop
        $json.body | Should -Be '{"ok":true}'
        $json.headers.'Content-Type' | Should -Be 'application/json; charset=utf-8'
    }

    It 'returns null for 404 without retrying' {
        $script:server.Enqueue(404, '{"error":"missing"}')
        Invoke-HuduRequest -Resource '/missing' -ErrorAction Stop | Should -BeNullOrEmpty
        $script:server.Requests.Count | Should -Be 1
    }

    It 'returns null after exhausted retries under ErrorAction Stop' {
        $script:server.Enqueue(500, '{"error":"failure"}')
        $script:server.Enqueue(500, '{"error":"failure"}')
        Invoke-HuduRequest -Resource '/failure' -ErrorAction Stop | Should -BeNullOrEmpty
        $script:server.Requests.Count | Should -Be 2
    }

    It 'quietly skips duplicate relations and restores retries using an existing migration pattern' {
        Set-HapiErrorsDirectory -Path $script:logs -skipRetry $true | Out-Null
        $script:server.Enqueue(422, '{"error":"Validation failed","details":["Fromable Can\u0027t create duplicate relations"]}')
        New-HuduRelation -FromableType Asset -FromableID 10 -ToableType Asset -ToableID 20 -ErrorAction Stop | Should -BeNullOrEmpty
        Set-HapiErrorsDirectory -skipRetry $false | Out-Null
        & (Get-Module HuduAPI) { $script:SKIP_HAPI_ERROR_RETRY } | Should -BeFalse
        @(Get-ChildItem $script:logs -Filter '*.log').Count | Should -Be 0
        Should -Invoke Write-Host -ModuleName HuduAPI -Times 0 -Exactly
        $script:server.Requests.Count | Should -Be 1
    }

    It 'reconnects after the server closes a connection' {
        $script:server.Enqueue(200, $null, $null, $true)
        (Invoke-HuduRequest -Resource '/first').path | Should -Be '/first'
        (Invoke-HuduRequest -Resource '/second').path | Should -Be '/second'
    }

    It 'keeps concurrent migration processes isolated on the same hostname' {
        $script:otherServer = [HuduAPI.Tests.LoopbackServer]::new()
        $script:server.Enqueue(200, $null, 'migration=A; Path=/')
        $script:otherServer.Enqueue(200, $null, 'migration=B; Path=/')
        $worker = {
            param($modulePath, $url, $tag)
            Import-Module $modulePath -Force -ErrorAction Stop
            & (Get-Module HuduAPI) {
                param($url, $tag)
                $script:Int_HuduBaseURL = $url
                $script:Int_HuduAPIKey = ConvertTo-SecureString ('key-' + $tag) -AsPlainText -Force
            } $url $tag
            foreach ($sequence in 1..10) {
                $body = @{ migration = $tag; sequence = $sequence } | ConvertTo-Json -Compress
                Invoke-HuduRequest -Method POST -Resource ('/migration/' + $tag) -Body $body -ErrorAction Stop | Out-Null
            }
            $PID
        }
        $jobs = @()
        try {
            $jobs += Start-Job -ScriptBlock $worker -ArgumentList $script:moduleUnderTest,$script:server.BaseUrl,'A'
            $jobs += Start-Job -ScriptBlock $worker -ArgumentList $script:moduleUnderTest,$script:otherServer.BaseUrl,'B'
            $jobs | Wait-Job -Timeout 30 | Out-Null
            @($jobs | Where-Object State -ne Completed).Count | Should -Be 0
            @($jobs | Receive-Job -ErrorAction Stop | Sort-Object -Unique).Count | Should -Be 2
            foreach ($pair in @(@{ Server = $script:server; Tag = 'A' }, @{ Server = $script:otherServer; Tag = 'B' })) {
                $pair.Server.Requests.Count | Should -Be 10
                foreach ($request in $pair.Server.Requests) {
                    $request.Path | Should -Be ('/migration/' + $pair.Tag)
                    $request.Headers['x-api-key'] | Should -Be ('key-' + $pair.Tag)
                    ($request.Body | ConvertFrom-Json).migration | Should -Be $pair.Tag
                    $request.Headers.ContainsKey('Cookie') | Should -BeFalse
                }
            }
        } finally {
            if ($jobs.Count) { $jobs | Stop-Job; $jobs | Remove-Job -Force }
        }
    }
}

Describe 'Unchanged community migration statements' -Tag Offline {
    BeforeAll {
        $script:communityRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '../Community-Scripts'
        function Get-CommunityFunction {
            param($Path, $Name)
            $tokens = $null; $errors = $null
            $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
            $function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name }, $true)
            if (-not $function) { throw "Community function not found: $Name" }
            $function.Extent.Text
        }
    }
    BeforeEach {
        $script:server = [HuduAPI.Tests.LoopbackServer]::new()
        $logs = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $logs | Out-Null
        & (Get-Module HuduAPI) {
            param($url, $logs)
            $script:Int_HuduWebSession = $null
            $script:Int_HuduCustomHeaders = $null
            $script:Int_HuduBaseURL = $url
            $script:Int_HuduAPIKey = ConvertTo-SecureString 'synthetic-key' -AsPlainText -Force
            $script:SKIP_HAPI_ERROR_RETRY = $false
            $script:SKIP_HAPI_POST_RETRY = $false
            $script:HAPI_RETRY_DELAY_SECONDS = 0
            $script:HAPI_ERRORS_DIRECTORY = $logs
        } $script:server.BaseUrl $logs
        $script:projectErrors = 0
        function Write-ErrorObjectsToFile { param($ErrorObject, $Name) $script:projectErrors++ }
        Mock Start-Sleep -ModuleName HuduAPI {}
        Mock Write-Host -ModuleName HuduAPI {}
    }
    AfterEach { $script:server.Dispose() }

    It 'restores retry settings after an ITBoost duplicate relation under Stop' {
        $path = Join-Path $script:communityRoot 'Migrations/ITBoost-Hudu-Migration/jobs/passwords.ps1'
        if (-not (Test-Path $path)) { Set-ItResult -Skipped -Because 'Community-Scripts checkout is unavailable'; return }
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        $call = $ast.Find({ param($node) $node -is [Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'new-hudurelation' -and $node.Extent.Text.Contains('$othermatch.id') }, $true)
        $statements = @($call.Parent.Parent.Statements)
        $index = [array]::IndexOf($statements, $call.Parent)
        $snippet = [scriptblock]::Create(($statements[($index-1)..($index+1)].Extent.Text -join [Environment]::NewLine))
        $newpass = [pscustomobject]@{ id = 88 }; $othermatch = [pscustomobject]@{ id = 10 }
        $script:server.Enqueue(422, '{"error":"Validation failed","details":["Fromable Can\u0027t create duplicate relations"]}')
        $preference = $global:ErrorActionPreference
        try { $global:ErrorActionPreference = 'Stop'; . $snippet | Out-Null }
        finally { $global:ErrorActionPreference = $preference }
        & (Get-Module HuduAPI) { $script:SKIP_HAPI_ERROR_RETRY } | Should -BeFalse
        $script:server.Requests.Count | Should -Be 1
    }

    It 'preserves the layout transfer move/update fallback and fetches current asset data' {
        $path = Join-Path $script:communityRoot 'Migrations/Migrating-Assets-Between-Layouts/Start-HuduAssetLayoutTransfer.ps1'
        if (-not (Test-Path $path)) { Set-ItResult -Skipped -Because 'Community-Scripts checkout is unavailable'; return }
        . ([scriptblock]::Create((Get-CommunityFunction $path 'Move-HuduAssetToNewLayout')))
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        $call = $ast.Find({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Move-HuduAssetToNewLayout' }, $true)
        $statement = $call
        while ($statement -and $statement -isnot [Management.Automation.Language.TryStatementAst]) { $statement = $statement.Parent }
        $snippet = [scriptblock]::Create($statement.Extent.Text)
        $originalasset = [pscustomobject]@{ id = 42; name = 'Original' }
        $destassetlayout = [pscustomobject]@{ id = 9; name = 'Destination' }
        $newAssetRequest = @{ Id = 42; Name = 'Moved'; AssetLayoutId = 9; Fields = @(@{ new_field = 'value' }) }
        $totalcounts = @{ assetsmoved = 0; assetsMovedInPlace = 0; auxiliaryRelinkSkipped = 0; errored = 0 }
        $script:server.Enqueue(200, '{"assets":[{"id":42,"company_id":7,"asset_layout_id":3}]}')
        $script:server.Enqueue(500, '{"error":"move response failed"}')
        $script:server.Enqueue(500, '{"error":"move response failed"}')
        $script:server.Enqueue(200, '{"assets":[{"id":42,"company_id":9,"asset_layout_id":9,"fields":[]}]}')
        $script:server.Enqueue(200, '{"asset":{"id":42,"company_id":9,"asset_layout_id":9}}')
        $preference = $global:ErrorActionPreference
        try { $global:ErrorActionPreference = 'Stop'; . $snippet | Out-Null }
        finally { $global:ErrorActionPreference = $preference }
        $script:projectErrors | Should -Be 0
        $totalcounts.assetsMovedInPlace | Should -Be 1
        $script:server.Requests.Count | Should -Be 5
        $script:server.Requests[4].Path | Should -Be '/api/v1/companies/9/assets/42'
    }

    It 'preserves the SharePoint request helper null result after exhausted retries' {
        $path = Join-Path $script:communityRoot 'Migrations/SharePoint-Hudu-Migration/jobs/Sync-SharePointDocumentsByCompanyTag.ps1'
        if (-not (Test-Path $path)) { Set-ItResult -Skipped -Because 'Community-Scripts checkout is unavailable'; return }
        . ([scriptblock]::Create((Get-CommunityFunction $path 'Invoke-TaggedDocumentSyncHuduRequest')))
        $script:server.Enqueue(500, '{"error":"server failure"}')
        $script:server.Enqueue(500, '{"error":"server failure"}')
        $preference = $global:ErrorActionPreference
        try {
            $global:ErrorActionPreference = 'Stop'
            Invoke-TaggedDocumentSyncHuduRequest -Method Put -Resource '/api/v1/articles/42' -Body '{"article":{"name":"Test"}}' |
                Should -BeNullOrEmpty
        } finally { $global:ErrorActionPreference = $preference }
        $script:server.Requests.Count | Should -Be 2
    }
}
