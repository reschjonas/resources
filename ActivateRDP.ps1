param(
    [switch]$Enable = $true
)

# Function to set RDP settings
function Set-RDPAccess {
    # Enable RDP connections
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value ([int](!$Enable))
    
    # Enable Network Level Authentication
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1
    
    # Configure Windows Firewall
    $rules = @(
        "Remote Desktop - User Mode (TCP-In)",
        "Remote Desktop - User Mode (UDP-In)",
        "Remote Desktop - Shadow (TCP-In)"
    )
    
    foreach ($rule in $rules) {
        try {
            $fwRule = Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
            if ($fwRule) {
                Set-NetFirewallRule -DisplayName $rule -Enabled $Enable
            }
        } catch {
            Write-Warning "Could not configure firewall rule: $rule"
        }
    }
    
    # Enable Remote Desktop Service
    try {
        $rdpService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
        if ($rdpService) {
            Set-Service -Name "TermService" -StartupType Automatic
            Start-Service -Name "TermService"
        }
    } catch {
        Write-Warning "Could not configure RDP service"
    }
    
    Write-Output "RDP has been $($Enable ? 'enabled' : 'disabled')"
}

# Ensure we're running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Script must run with administrative privileges"
    exit 1
}

# Execute the configuration
Set-RDPAccess -Enable $Enable
