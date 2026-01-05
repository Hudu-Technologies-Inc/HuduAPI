function Set-FlagableFromCanonical {
    param ([string]$inputData)
    if ([string]::IsNullOrWhiteSpace($inputData)) { return $null }

        if (-not $(get-variable -name 'script:FlaggableTypeLookup' -scope 'script' -erroraction silentlycontinue)) {
            $script:FlaggableTypeMap = [ordered]@{
                Asset         = @('assets','asset')
                Website       = @('website')
                Article       = @('article','articles','kb','knowledgebase')
                AssetPassword = @('assetpassword','asset_password','password')
                Company       = @('company','companies')
                Procedure     = @('procedure','process')
                RackStorage   = @('rackstorage','rack_storage','rack','rackstorages')
                Network       = @('network')
                IpAddress     = @('ipaddress','ip_address','ip')
                Vlan          = @('vlan','vlans')
                VlanZone      = @('vlanzone','vlan_zone','zone')
            }
            $script:FlaggableTypeLookup = @{}
            foreach ($canonical in $script:FlaggableTypeMap.Keys) {
                # include canonical itself as accepted input
                $all = @($canonical) + $script:FlaggableTypeMap[$canonical]

                foreach ($v in $all) {
                    if ([string]::IsNullOrWhiteSpace($v)) { continue }
                    $k = ($v -as [string]).Trim().ToLowerInvariant()
                    $k = $k -replace '[-\s]+','_'      # treat dashes/spaces like underscores
                    $script:FlaggableTypeLookup[$k] = $canonical
                }
            }            
        }               

        $raw = ([string]$inputData).Trim()
        if ($raw.Length -eq 0) { return $raw }

        $k = $raw.ToLowerInvariant() -replace '[-\s]+','_'

        $lookup = $script:FlaggableTypeLookup
        if ($lookup.ContainsKey($k)) {
            return $lookup[$k]
        }
        $allowed = ($script:FlaggableTypeMap.Keys -join ', ')
        throw "Invalid flaggable type '$raw'. Allowed: $allowed"
}

