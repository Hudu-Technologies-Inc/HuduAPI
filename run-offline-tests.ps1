#requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$CompatibilityOnly,
    [string]$ModulePath = (Join-Path $PSScriptRoot 'HuduAPI/HuduAPI.psd1'),
    [string[]]$ExcludeTag = @(),
    [string]$ResultsPath = (Join-Path $PSScriptRoot 'Output/offline-tests.xml')
)

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
if ($PSBoundParameters.ContainsKey('ModulePath') -and -not $CompatibilityOnly) {
    throw '-ModulePath requires -CompatibilityOnly; the other suites load the working-tree module.'
}
$testRoot = Join-Path $PSScriptRoot 'HuduAPI/tests'
$config = New-PesterConfiguration
$containers = @(New-PesterContainer -Path (Join-Path $testRoot 'Compatibility.Tests.ps1') -Data @{ ModulePath = $ModulePath })
if (-not $CompatibilityOnly) {
    # Explicit allowlist: all other suites contact Hudu and may modify/delete records.
    foreach ($name in @(
        'AssetLayout.NumberFields.Tests.ps1', 'FeatureAvailability.Tests.ps1',
        'Move-HuduCompany.Tests.ps1', 'PasswordShares.Tests.ps1',
        'RackStorage.Payloads.Tests.ps1', 'RequestHandling.Tests.ps1'
    )) {
        $containers += New-PesterContainer -Path (Join-Path $testRoot $name)
    }
}
$config.Run.Container = $containers
$config.Run.PassThru = $true
$config.Filter.ExcludeTag = $ExcludeTag
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = [IO.Path]::GetFullPath($ResultsPath)
$config.TestResult.OutputFormat = 'NUnitXml'
$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0 -or $result.FailedBlocksCount -gt 0 -or $result.FailedContainersCount -gt 0 -or $result.TotalCount -eq 0) { exit 1 }
