# Get the current username
$CurrentUser = [Environment]::UserName

# Change the username to "New Name"
Rename-LocalUser -Name $CurrentUser -NewName "New Name" -ErrorAction SilentlyContinue
