######################################################################################################
#                                                                                                    #
#                                            CAA-Tool.ps1                                            #
#                                                                                                    #
######################################################################################################

param(
    [switch]$ScanOnly = $false
)

#region functions
#====================================================================================================#
#                                           [ Functions ]                                            #
#====================================================================================================#
function Test-IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $ScanOnly) {
    if (-not (Test-IsAdmin)) {
        Write-Host "[ERROR] This script requires admin rights for remediation. Please run PowerShell as Administrator."
        exit 1
    }
}

$BaseURL = "https://raw.githubusercontent.com/HTTP-218/Endpoint_Verification/main"

Invoke-Expression (Invoke-RestMethod "$BaseURL/Modules/CAA-Logs.psm1")
Invoke-Expression (Invoke-RestMethod "$BaseURL/Modules/CAA-Scan.psm1")
Invoke-Expression (Invoke-RestMethod "$BaseURL/Modules/CAA-Remediate.psm1")
Invoke-Expression (Invoke-RestMethod "$BaseURL/Functions/Get-CurrentUser.ps1")
#endregion

#region variables
#====================================================================================================#
#                                           [ Variables ]                                            #
#====================================================================================================#
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'
$LogFilePath = "C:\Windows\Temp\CAA-Tool.log"
Set-LogFilePath "C:\Windows\Temp\CAA-Tool.log"
$Summary = [System.Collections.Generic.List[string]]::new()
$Username = Get-CurrentUser

Add-Type -AssemblyName System.Windows.Forms
#endregion

#region JSON
#====================================================================================================#
#                                        [ Load JSON Config ]                                        #
#====================================================================================================#
$JSONPath = "C:\Windows\Temp\caa.json"

try {
    Invoke-WebRequest -Uri "$BaseURL/caa.json" -OutFile $JSONPath
    $Variables = Get-Content -Raw -Path $JSONPath | ConvertFrom-Json
}
catch {
    Write-Message -Message "Failed to initialise JSON config file`n`n$($_.Exception.Message)" -Level "ERROR" -Dialogue $true
    exit 1
}
#endregion

#region Main
#====================================================================================================#
#                                           [ Main Logic ]                                           #
#====================================================================================================#
Set-Content -Path $LogFilePath -Encoding Unicode -Value "
##########################################################################
#                                                                        #
#                              CAA-Tool.ps1                              #
#                                                                        #
##########################################################################
"

#region Windows Check
#============================
$WindowsBuildCheck = Get-WindowsBuild -BuildRequirements $Variables.BuildRequirements
if ($WindowsBuildCheck.IsCompliant -eq $false) {
    $Summary.Add($WindowsBuildCheck.Message)
}
#endregion

#region Chrome Check
#============================
$ChromeCheck = Get-ChromeStatus -ChromeVersion $Variables.ChromeVersion
if ($ChromeCheck.IsCompliant -eq $false -and $ChromeCheck.Message -eq "Chrome is not installed") {

    if (-not $ScanOnly) {    
        $InstallResponse = Show-MessageBox -Message "Google Chrome is missing.`n`nWould you like to install it now?" -Title "Install Google Chrome?" -Icon "Question" -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo)
    
        if ($InstallResponse -eq [System.Windows.Forms.DialogResult]::Yes) {
            Install-GoogleChrome
        }
        else {
            Write-Message -Message "User chose not to install Google Chrome." -Level "NOTICE"
            $Summary.Add("Google Chrome is not installed")
        } 
    }
    else {
        $Summary.Add($ChromeCheck.Message)
    }
}
elseif ($ChromeCheck.IsCompliant -eq $false) {
    $Summary.Add($ChromeCheck.Message)
}
#endregion

#region Extension Check
#============================
$EVExtensionCheck = Get-EVExtensionStatus -Username $Username -ExtensionID $Variables.ExtensionID
if ($EVExtensionCheck.IsCompliant -eq $false) {
    $Summary.Add($EVExtensionCheck.Message)
}
#endregion

#region Firewall Check
#============================
$FirewallCheck = Get-FirewallStatus
if (-not $FirewallCheck.IsCompliant) {
    if (-not $ScanOnly) {
        foreach ($ProfileName in $FirewallCheck.DisabledProfiles) {
            $EnableResponse = Show-MessageBox -Message "The $ProfileName firewall profile is disabled.`n`nWould you like to enable it?" -Title "Enable Firewall Profile?" -Icon "Question" -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo)

            if ($EnableResponse -eq [System.Windows.Forms.DialogResult]::Yes) {
                try {
                    Enable-FirewallProfiles -Profiles @($ProfileName)
                }
                catch {
                    $Summary.Add("Failed to enable $ProfileName firewall profile")
                }
            }
            else {
                Write-Message -Message "User chose not to enable the $ProfileName firewall profile." -Level "NOTICE"
                $Summary.Add("$ProfileName firewall profile is disabled")
            }
        }
    }
    else {
        foreach ($Message in $FirewallCheck.Message) {
            $Summary.Add($Message)
        }
    }
}
#endregion

#region EV Helper App Check
#============================
$EVHelperAppCheck = Get-EVHelperStatus
if ($EVHelperAppCheck.IsCompliant -eq $false) {
    
    if (-not $ScanOnly) { 
        $InstallResponse = Show-MessageBox -Message "Endpoint Verification Helper is missing.`n`nWould you like to install it now?" -Title "Install EV Helper?" -Icon "Question" -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo)
    
        if ($InstallResponse -eq [System.Windows.Forms.DialogResult]::Yes) {
            Install-EVHelperApp
        }
        else {
            Write-Message -Message "User chose not to install EV Helper App." -Level "NOTICE"
            $Summary.Add("EVHelperApp is not installed")
        }
    }
    else {
        $Summary.Add($EVHelperAppCheck.Message)
    }
}
#endregion

#region Cleanup
#====================================================================================================#
#                                             [ Cleanup ]                                            #
#====================================================================================================#
Write-Message -Message "========== Clean Up ==========" -Level "INFO"

Write-Message -Message  "Deleting JSON file..." -Level "INFO"
try {
    Remove-Item $JSONPath -Force
    Write-Message -Message  "JSON file deleted" -Level "NOTICE"     
}
catch {
    Write-Message -Message  "Failed to delete JSON file: $($_.Exception.Message)" -Level "WARN"
}
#endregion

#region Summary
#====================================================================================================#
#                                       [ Compliance Summary ]                                       #
#====================================================================================================#
Write-Message -Message  "========== Summary ==========" -Level "INFO"
Write-Message -Message  "Generating summary report..." -Level "INFO"

if ($Summary.Count -eq 0) {
    $Message = @"
    All checks passed. Your device is compliant.

    If you're still unable to access Gmail, try the following:

      1. Open Google Chrome and wait 2 minutes
      2. Open the Endpoint Verification extension
      3. Click 'SYNC NOW'
      4. Reload your Gmail tab
"@
    Write-Message -Message $Message -Level "INFO" -Console $false -Log $false -Dialogue $true
} 
else {
    $SummaryText = ($Summary | ForEach-Object { "    - $_" }) -join "`n"
    $Message = @"
    Your device is not compliant:

$SummaryText

Please address each issue, then run the Endpoint Verification sync to regain access.
"@
    Write-Message -Message $Message -Level "ERROR" -Console $false -Log $false -Dialogue $true
}

exit 0
#endregion

#endregion
