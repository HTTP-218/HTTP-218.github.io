# Self-elevate if not running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Kill all Chrome instances
$ChromeProcessIDs = (get-process -ProcessName chrome -ErrorAction SilentlyContinue).Id
foreach ($ID in $ChromeProcessIDs) {
    Stop-Process -Id $ID -Force -ErrorAction SilentlyContinue
}

# Stop Google services
$ChromeServices = Get-Service | where-object { $_.Name -like 'Google*' }

foreach ($Service in $ChromeServices) {
    if ($Service.Status -ne 'Stopped') {
        try {
            Stop-Service -InputObject $Service -Force -ErrorAction Stop
            Write-Host "Stopped $($Service.Name) service."
        }
        catch {
            Write-Host "Failed to stop $($Service.Name): $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "$($Service.Name) service already stopped."
    }
}

# Uninstall Chrome
$UninstallKeys = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$Chrome = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue| Where-Object { $_.DisplayName -eq 'Google Chrome' }

if (-not $Chrome) {
    Write-Host "Chrome not found in registry uninstall keys."
    exit 0
}

foreach ($Entry in $Chrome) {
    $UninstallString = $Entry.UninstallString

    if ($Entry.WindowsInstaller -eq 1 -or $UninstallString -match 'MsiExec') {
        # Check if Chrome was installed with MSI package
        if ($UninstallString -match '\{[0-9A-Fa-f\-]+\}') {
            $ProductCode = $Matches[0]
            Write-Host "Detected MSI install. Uninstalling with msiexec, product code $ProductCode"
            Start-Process "msiexec.exe" -ArgumentList "/x $ProductCode /qn /norestart" -Wait
        } 
        else {
            Write-Host "WindowsInstaller=1 but couldn't parse product code from: $UninstallString"
        }
    }
    elseif ($UninstallString -match '^"?(.+?\.exe)"?(.*)$') {
        # Check if Chrome was installed with exe based install (machine-wide or per-user)
        $ExePath = $Matches[1]
        $ExistingArgs = $Matches[2].Trim()

        if (-not (Test-Path $ExePath)) {
            Write-Host "Uninstaller exe not found at: $ExePath"
            continue
        }

        # Build args: ensure silent uninstall flags are present
        $ArgList = $ExistingArgs
        if ($ArgList -notmatch '--force-uninstall') {
            $ArgList += ' --force-uninstall'
        }

        Write-Host "Detected setup.exe install. Running: `"$ExePath`" $ArgList"
        Start-Process -FilePath $ExePath -ArgumentList $ArgList -Wait
    }
    else {
        Write-Host "Unrecognized UninstallString format: $UninstallString"
    }
}

# Verify Chrome was removed
$MaxRetries = 5
$RetryCount = 0
$StillRegistered = $true

while ($RetryCount -lt $MaxRetries -and $StillRegistered) {
    Start-Sleep -Seconds 5
    $StillRegistered = [bool](Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq 'Google Chrome' })
    $RetryCount++
    Write-Host "Check [$RetryCount/$MaxRetries] - still registered: $StillRegistered"
}

if ($StillRegistered) {
    Write-Host "Uninstall did not complete after $($MaxRetries * 5) seconds. Skipping cleanup."
    exit 1
}

Write-Host "Uninstall verified after $RetryCount check(s). Proceeding with cleanup."

# Delete Google services
foreach ($Service in $ChromeServices) {
    $Result = & sc.exe DELETE $Service.Name
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$($Service.Name) service deleted."
    }
    else {
        Write-Host "Failed to delete $($Service.Name): $result"
    }
}  

# Remove any scheduled tasks
$ScheduledTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like '*Google*' -or $_.TaskName -like '*Chrome*' }

foreach ($Task in $ScheduledTasks) {
    Unregister-ScheduledTask -TaskName $Task.TaskName -Confirm:$false
    Write-Host "$($Task.TaskName) task was removed."
}

# Backup AppData UserProfiles
$BackupPath = "C:\Temp\ChromeProfileBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$UserDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$ExcludedDirectories = @('Cache', 'Code Cache', 'GPUCache', 'Crashpad')

if (Test-Path $UserDataPath) {
    try {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        Copy-Item -Path $UserDataPath -Destination $BackupPath -Recurse -Force -Exclude $ExcludedDirectories
        Write-Host "Backed up Chrome User Data to $BackupPath"
    }
    catch {
        Write-Host "Failed to back up Chrome profile data: $($_.Exception.Message)"
    }
}

# Remove Chrome Program Files and AppData Folders
$PathsToRemove = @(
    "$env:LOCALAPPDATA\Google\Chrome",
    "$env:APPDATA\Google\Chrome",
    "C:\Program Files\Google\Chrome",
    "C:\Program Files (x86)\Google\Chrome"
)

foreach ($Path in $PathsToRemove) {
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force
            Write-Host "Removed: $Path"
        }
        catch {
            Write-Host "Failed to remove $Path : $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "Not found, skipping: $Path"
    }
}

# Remove Chrome Registry keys
$RegistryPathsToRemove = @(
    "HKCU:\Software\Google\Chrome",
    "HKLM:\Software\Google\Chrome",
    "HKLM:\Software\WOW6432Node\Google\Chrome",
    "HKCU:\Software\Policies\Google\Chrome",
    "HKLM:\Software\Policies\Google\Chrome",
    "HKLM:\Software\WOW6432Node\Policies\Google\Chrome"
)

foreach ($RegistryPath in $RegistryPathsToRemove) {
    if (Test-Path $RegistryPath) {
        try {
            Remove-Item -Path $RegistryPath -Recurse -Force -ErrorAction Stop
            Write-Host "Removed registry key: $RegistryPath"
        }
        catch {
            Write-Host "Note: $RegistryPath - $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "Not found, skipping: $RegistryPath"
    }
}

Start-Sleep -Seconds 2

# Reinstall Chrome
$ChromeEntURL = "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi"
$ChromeMSIPath = Join-Path $env:TEMP "googlechromestandaloneenterprise64.msi"

Write-Host "Checking if Chrome MSI file is present..."

if (!(Test-Path $ChromeMSIPath)) {
    Write-Host "MSI file is missing, downloading Google Chrome MSI file. This may take a few minutes..."
    try {
        Invoke-WebRequest $ChromeEntURL -OutFile $ChromeMSIPath
        Write-Host "Downloaded Google Chrome MSI file"
    }
    catch {
        Write-Host "Failed to download Google Chrome MSI file: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Host "Chrome MSI file has already been downloaded"
}

Write-Host "Installing Google Chrome..."
$InstallProc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ChromeMSIPath`" /qn /norestart" -Wait -PassThru

if ($InstallProc.ExitCode -ne 0) {
    Write-Host "Chrome install failed with exit code $($InstallProc.ExitCode)"
    exit 1
}
else {
    Write-Host "Google Chrome has been installed!"
    Write-Host "Removing MSI file..."
    try {    
        Remove-Item $ChromeMSIPath -Force
        Write-Host "Chrome MSI file deleted"
    }
    catch {
        Write-Host "Failed to delete Chrome MSI file: $($_.Exception.Message)"
    }    
}

try {
    Start-Process -FilePath "C:\Program Files\Google\Chrome\Application\chrome.exe"
}
catch {
    Write-Host "Chrome installed but failed to launch: $($_.Exception.Message)"
}

Write-Host "Done!"