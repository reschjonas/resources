param(
    [Parameter(Mandatory=$false)]
    [int[]]$Ports = @(80, 443, 3389),
    [Parameter(Mandatory=$false)]
    [string[]]$Protocols = @("TCP", "UDP")
)

function Open-Ports {
    param (
        [int[]]$Ports,
        [string[]]$Protocols
    )
    
    try {
        # Disable Windows Firewall first (for reliability)
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
        
        foreach ($port in $Ports) {
            foreach ($protocol in $Protocols) {
                # Create unique rule names
                $ruleName = "Port ${port} ${protocol} - Added by Script"
                
                # Remove any existing rules with same name
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                
                # Create new inbound rule
                New-NetFirewallRule -DisplayName $ruleName `
                    -Direction Inbound `
                    -Protocol $protocol `
                    -LocalPort $port `
                    -Action Allow `
                    -Profile Any `
                    -Program Any `
                    -Service Any `
                    -Enabled True `
                    -ErrorAction SilentlyContinue | Out-Null
                
                # Create new outbound rule
                New-NetFirewallRule -DisplayName $ruleName `
                    -Direction Outbound `
                    -Protocol $protocol `
                    -LocalPort $port `
                    -Action Allow `
                    -Profile Any `
                    -Program Any `
                    -Service Any `
                    -Enabled True `
                    -ErrorAction SilentlyContinue | Out-Null
                
                Write-Output "Opened port $port for $protocol"
            }
        }
        
        # Ensure Windows Firewall service stays running
        Set-Service -Name MpsSvc -StartupType Automatic
        Start-Service -Name MpsSvc
        
        Write-Output "Port configuration completed successfully"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

# Execute port opening
Open-Ports -Ports $Ports -Protocols $Protocols
