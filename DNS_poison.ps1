param(
    [string]$RedirectIP = "127.0.0.1",
    [string[]]$TargetDomains = @("example.com", "www.example.com")
)

function Set-DNSPoison {
    param (
        [string]$IP,
        [string[]]$Domains
    )
    
    try {
        # Path to hosts file
        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
        
        # Backup original hosts file
        Copy-Item $hostsFile "$hostsFile.bak" -Force
        
        # Get current content
        $current = Get-Content $hostsFile -ErrorAction SilentlyContinue
        
        # Create new entries
        $entries = $Domains | ForEach-Object {
            "$IP `t$_"
        }
        
        # Combine existing and new entries
        $newContent = @()
        if ($current) {
            $newContent += $current
        }
        $newContent += ""
        $newContent += "# Added by DNS Poison Demo"
        $newContent += $entries
        
        # Write new hosts file
        $newContent | Set-Content -Path $hostsFile -Force
        
        # Flush DNS cache
        Clear-DnsClientCache
        
        # Restart DNS client service
        Restart-Service -Name Dnscache -Force
        
        Write-Output "DNS poisoning completed for: $($Domains -join ', ')"
        Write-Output "Redirecting to: $IP"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

Set-DNSPoison -IP $RedirectIP -Domains $TargetDomains
