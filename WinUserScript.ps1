param(
    [string]$NewName = "Default Name"
)

# Get the current username and rename
$CurrentUser = [Environment]::UserName
Rename-LocalUser -Name $CurrentUser -NewName $NewName -ErrorAction SilentlyContinue
