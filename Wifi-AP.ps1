param(
    [Parameter(Mandatory=$false)]
    [string]$SSID = "Evil-Twin",
    [Parameter(Mandatory=$false)]
    [string]$Password = "Password123!",
    [Parameter(Mandatory=$false)]
    [switch]$ShareInternet = $true
)

function Start-WifiHotspot {
    param (
        [string]$NetworkName,
        [string]$NetworkPass,
        [bool]$ShareNet
    )
    
    try {
        # Stop any existing hosted network
        Start-Process "netsh" -ArgumentList "wlan stop hostednetwork" -WindowStyle Hidden -Wait
        
        # Enable Microsoft Hosted Network Service
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='SharedAccess'"
        if ($service) {
            $service.StartMode = "Auto"
            $service.Change($null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null)
            $service.StartService()
        }
        
        # Configure hosted network
        $configResult = Start-Process "netsh" -ArgumentList "wlan set hostednetwork mode=allow ssid=`"$NetworkName`" key=`"$NetworkPass`"" -WindowStyle Hidden -Wait -PassThru
        
        if ($configResult.ExitCode -eq 0) {
            # Start the hosted network
            $startResult = Start-Process "netsh" -ArgumentList "wlan start hostednetwork" -WindowStyle Hidden -Wait -PassThru
            
            if ($startResult.ExitCode -eq 0) {
                Write-Output "WiFi hotspot started successfully"
                Write-Output "SSID: $NetworkName"
                Write-Output "Password: $NetworkPass"
                
                if ($ShareNet) {
                    # Enable Internet Connection Sharing
                    try {
                        # Get network adapters
                        $mainAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.MediaType -ne "802.11" } | Select-Object -First 1
                        $hostedAdapter = Get-NetAdapter | Where-Object { $_.Description -like "*Microsoft Hosted Network Virtual Adapter*" } | Select-Object -First 1
                        
                        if ($mainAdapter -and $hostedAdapter) {
                            # Enable ICS
                            $regKey = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters"
                            Set-ItemProperty -Path $regKey -Name "SharingEnabled" -Value 1
                            
                            # Configure sharing on main adapter
                            $shell = New-Object -ComObject HNetCfg.HNetShare
                            $connection = $shell.EnumEveryConnection | Where-Object { $shell.NetConnectionProps($_).Name -eq $mainAdapter.Name }
                            $config = $shell.INetSharingConfigurationForINetConnection($connection)
                            $config.EnableSharing(0)
                            
                            Write-Output "Internet sharing enabled"
                        }
                    } catch {
                        Write-Warning "Could not enable Internet sharing: $_"
                    }
                }
            } else {
                throw "Failed to start hotspot"
            }
        } else {
            throw "Failed to configure hotspot"
        }
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

# Execute hotspot creation
Start-WifiHotspot -NetworkName $SSID -NetworkPass $Password -ShareNet $ShareInternet
