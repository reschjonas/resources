param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "YOUR-WEBHOOK-URL-HERE"
)

function Get-WindowsUpdateList {
    param($webhook)
    
    try {
        $info = @()
        $info += "=== WINDOWS UPDATES REPORT ==="
        $info += "Generated: $(Get-Date)"
        $info += "Computer: $env:COMPUTERNAME"
        $info += "User: $env:USERNAME"
        $info += "=========================="
        
        # Get all installed updates
        $updates = Get-HotFix | Sort-Object -Property InstalledOn -Descending
        
        # Group updates by type
        $securityUpdates = $updates | Where-Object { $_.Description -like "*Security Update*" }
        $hotfixes = $updates | Where-Object { $_.Description -like "*Hotfix*" }
        $servicePacks = $updates | Where-Object { $_.Description -like "*Service Pack*" }
        $updates = $updates | Where-Object { 
            $_.Description -notlike "*Security Update*" -and 
            $_.Description -notlike "*Hotfix*" -and 
            $_.Description -notlike "*Service Pack*"
        }
        
        # Format Security Updates
        if ($securityUpdates) {
            $info += "`nSECURITY UPDATES:"
            $securityUpdates | ForEach-Object {
                $info += "KB$($_.HotFixID) - Installed: $($_.InstalledOn)"
                $info += "  Source: $($_.InstalledBy)"
                $info += "  Type: $($_.Description)"
            }
        }
        
        # Format Hotfixes
        if ($hotfixes) {
            $info += "`nHOTFIXES:"
            $hotfixes | ForEach-Object {
                $info += "KB$($_.HotFixID) - Installed: $($_.InstalledOn)"
                $info += "  Source: $($_.InstalledBy)"
                $info += "  Type: $($_.Description)"
            }
        }
        
        # Format Service Packs
        if ($servicePacks) {
            $info += "`nSERVICE PACKS:"
            $servicePacks | ForEach-Object {
                $info += "KB$($_.HotFixID) - Installed: $($_.InstalledOn)"
                $info += "  Source: $($_.InstalledBy)"
                $info += "  Type: $($_.Description)"
            }
        }
        
        # Format Other Updates
        if ($updates) {
            $info += "`nOTHER UPDATES:"
            $updates | ForEach-Object {
                $info += "KB$($_.HotFixID) - Installed: $($_.InstalledOn)"
                $info += "  Source: $($_.InstalledBy)"
                $info += "  Type: $($_.Description)"
            }
        }
        
        # Get Windows Update Service Status
        $wuauserv = Get-Service -Name wuauserv
        $info += "`nWINDOWS UPDATE SERVICE:"
        $info += "Status: $($wuauserv.Status)"
        $info += "Start Type: $($wuauserv.StartType)"
        
        # Get Update Policy
        try {
            $updatePolicy = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue
            if ($updatePolicy) {
                $info += "`nUPDATE POLICY:"
                $info += "Auto Update: $($updatePolicy.NoAutoUpdate -eq 0)"
                $info += "Auto Install: $($updatePolicy.AUOptions)"
            }
        } catch {}
        
        # Split and send content (Discord has 2000 char limit)
        $content = $info -join "`n"
        $chunks = [regex]::Matches($content, ".{1,1900}")
        
        foreach ($chunk in $chunks) {
            $payload = @{
                content = "```$($chunk.Value)```"
                username = "Windows Update Info"
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType "application/json"
            Start-Sleep -Seconds 1
        }
        
        Write-Output "Windows Update information sent to Discord"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Execute the update list gathering
Get-WindowsUpdateList -webhook $WebhookUrl
