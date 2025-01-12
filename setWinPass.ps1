param(
    [Parameter(Mandatory=$false)]
    [string]$NewPassword = "P@ssw0rd123!",
    [Parameter(Mandatory=$false)]
    [string]$Username = $null
)

function Set-WindowsPassword {
    param (
        [string]$Password,
        [string]$TargetUser
    )
    
    try {
        # If no username specified, get current user
        if (!$TargetUser) {
            $TargetUser = [Environment]::UserName
        }
        
        # Convert password to secure string
        $SecurePass = ConvertTo-SecureString $Password -AsPlainText -Force
        
        # Try multiple methods to ensure success
        try {
            # Method 1: Set-LocalUser (preferred)
            Set-LocalUser -Name $TargetUser -Password $SecurePass -ErrorAction Stop
        } catch {
            try {
                # Method 2: NET USER command
                $process = Start-Process "net" -ArgumentList "user",$TargetUser,$Password -WindowStyle Hidden -Wait -PassThru
                if ($process.ExitCode -ne 0) { throw "NET USER failed" }
            } catch {
                # Method 3: ADSI
                $account = [ADSI]"WinNT://localhost/$TargetUser,user"
                $account.SetPassword($Password)
                $account.SetInfo()
            }
        }
        
        # Disable password expiration and complexity requirements
        try {
            Set-LocalUser -Name $TargetUser -PasswordNeverExpires $true
            # Disable password complexity via registry
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
            if (!(Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
            Set-ItemProperty -Path $path -Name "MinimumPasswordLength" -Value 0 -Type DWORD
            Set-ItemProperty -Path $path -Name "PasswordComplexity" -Value 0 -Type DWORD
        } catch {
            Write-Warning "Could not modify password policies"
        }
        
        Write-Output "Password successfully changed for user: $TargetUser"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

# Execute password change
Set-WindowsPassword -Password $NewPassword -TargetUser $Username
