
Function Set-ColorFromCanonical {
    param (
        [string] $inputData
    ) 
    if ([string]::IsNullOrWhiteSpace($inputData)) { return $null }
    if (-not $(get-variable -name 'script:ColorLookup' -scope 'script' -erroraction silentlycontinue)) {
        $script:ColorMap = [ordered]@{
            Red          = @('red','crimson','scarlet')
            Blue         = @('blue','navy')
            Green        = @('green','lime')
            Yellow       = @('yellow','gold')
            Purple       = @('purple','violet')
            Orange       = @('orange')
            LightPink    = @('light pink','pink','baby pink')
            LightBlue    = @('light blue','baby blue','sky blue')
            LightGreen   = @('light green','mint')
            LightPurple  = @('light purple','lavender')
            LightOrange  = @('light orange','peach')
            LightYellow  = @('light yellow','cream')
            White        = @('white')
            Grey         = @('grey','gray','silver')
        }
    $script:ColorLookup = @{}
    foreach ($canonical in $script:ColorMap.Keys) {
        $all = @($canonical) + $script:ColorMap[$canonical]
        foreach ($v in $all) {
            if (-not $v) { continue }

            $k = $v.ToLowerInvariant()
            $k = $k -replace '[-\s]+','_'    # normalize separators
            $script:ColorLookup[$k] = $canonical
        }
    }        
    }

    $raw = ([string]$inputData).Trim()
    if ($raw.Length -eq 0) { return $raw }

    $key = $raw.ToLowerInvariant() -replace '[-\s]+','_'

    if ($script:ColorLookup.ContainsKey($key)) {
        return $script:ColorLookup[$key]
    }

    $allowed = ($script:ColorMap.Keys -join ', ')
    throw "Invalid color '$raw'. Allowed values: $allowed"
}