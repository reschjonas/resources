param(
    [Parameter(Mandatory=$false)]
    [string[]]$UpdateIDs = @("KB5034441", "KB5034440"),  # Example updates
    [switch]$RemoveAll = $false
)

function Remove-WindowsUpdates {
    param (
        [string[]]$Updates,
        [bool]$RemoveAllUpdates
    )
    
    try {
        # Disable Windows Update service first
        $services = @(
            "wuauserv",          # Windows Update
            "UsoSvc",            # Update Orchestrator Service
            "WaaSMedicSvc",      # Windows Update Medic Service
            "bits"               # Background Intelligent Transfer
        )
        
        foreach ($service in $services) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        }
        
        if ($RemoveAllUpdates) {
            # Get all installed updates
            $allUpdates = Get-HotFix | Select-Object -ExpandProperty HotFixID
            $Updates = $allUpdates
        }
        
        foreach ($update in $Updates) {
            # Clean up KB number format
            $kb = $update.Replace("KB", "").Trim()
            
            Write-Output "Attempting to remove update KB$kb..."
            
            # Try multiple removal methods
            try {
                # Method 1: wusa
                $process = Start-Process -FilePath "wusa.exe" -ArgumentList "/uninstall /kb:$kb /quiet /norestart" -Wait -PassThru -WindowStyle Hidden
                
                # Method 2: DISM if wusa fails
                if ($process.ExitCode -ne 0) {
                    $process = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Remove-Package /PackageName:*KB$kb* /Quiet /NoRestart" -Wait -PassThru -WindowStyle Hidden
                }
                
                Write-Output "Successfully processed KB$kb"
                
            } catch {
                Write-Warning "Failed to remove KB$kb: $_"
            }
        }
        
        # Clear Windows Update cache
        Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Output "Update removal process completed"
        
    } catch {
        Write-Warning "Operation failed: $_"
    } finally {
        # Re-enable services (commented out for persistence)
        # foreach ($service in $services) {
        #     Set-Service -Name $service -StartupType Automatic
        #     Start-Service -Name $service
        # }
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

# Execute update removal
Remove-WindowsUpdates -Updates $UpdateIDs -RemoveAllUpdates $RemoveAll
