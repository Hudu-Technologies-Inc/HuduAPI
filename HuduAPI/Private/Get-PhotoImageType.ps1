function Get-PhotoImageType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]$Path,

        [ValidateRange(16, 4096)]
        [int]$MaxBytes = 64
    )

    begin {
        function Test-Bytes {
            param(
                [byte[]]$Data,
                [int]$Offset,
                [byte[]]$Pattern
            )
            if ($null -eq $Data) { return $false }
            if ($Offset -lt 0) { return $false }
            if ($Data.Length -lt ($Offset + $Pattern.Length)) { return $false }
            for ($i = 0; $i -lt $Pattern.Length; $i++) {
                if ($Data[$Offset + $i] -ne $Pattern[$i]) { return $false }
            }
            return $true
        }

        function Get-Ascii {
            param([byte[]]$Data, [int]$Offset, [int]$Count)
            if ($Data.Length -lt ($Offset + $Count)) { return $null }
            return [System.Text.Encoding]::ASCII.GetString($Data, $Offset, $Count)
        }
    }

    process {
        # Resolve + reject non-files early
        $full = $null
        try { $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path }
        catch { return 'unknown' }

        $item = Get-Item -LiteralPath $full -ErrorAction SilentlyContinue
        if ($null -eq $item -or $item.PSIsContainer) { return 'unknown' }

        # Read a small header
        $buf = New-Object byte[] $MaxBytes
        $read = 0
        try {
            $fs = [System.IO.File]::Open($full, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try { $read = $fs.Read($buf, 0, $buf.Length) }
            finally { $fs.Dispose() }
        } catch {
            return 'unknown'
        }

        if ($read -lt 12) { return 'unknown' }  # need at least this much for WebP/ftyp checks
        $data = if ($read -eq $buf.Length) { $buf } else { $buf[0..($read-1)] }

        # JPEG: FF D8 FF
        if (Test-Bytes $data 0 ([byte[]](0xFF,0xD8,0xFF))) { return 'jpeg' }

        # PNG: 89 50 4E 47 0D 0A 1A 0A
        if (Test-Bytes $data 0 ([byte[]](0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A))) { return 'png' }

        # GIF: GIF87a / GIF89a
        $gif = Get-Ascii $data 0 6
        if ($gif -eq 'GIF87a' -or $gif -eq 'GIF89a') { return 'gif' }

        # WebP: RIFF....WEBP
        if ((Get-Ascii $data 0 4) -eq 'RIFF' -and (Get-Ascii $data 8 4) -eq 'WEBP') { return 'webp' }

        # HEIC/HEIF: ISOBMFF ftyp + major brand
        if ((Get-Ascii $data 4 4) -eq 'ftyp') {
            $brand = Get-Ascii $data 8 4
            # keep this list tight; expand if you want AVIF, etc.
            if ($brand -in @('heic','heix','hevc','hevx','mif1','msf1','heim','heis')) { return 'heic' }
        }

        return 'unknown'
    }
}