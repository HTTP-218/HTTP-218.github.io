######################################################################################################
#                                                                                                    #
#                                             Launch.ps1                                             #
#                                                                                                    #
######################################################################################################

$RepoURL = "https://raw.githubusercontent.com/HTTP-218/Endpoint_Verification/main/CAA-Tool.ps1"
$PS5Path = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$ToolPath = Join-Path $env:TEMP "CAA-Tool.ps1"

$asciiBanner = @"
           _   _ _____ _____ ____      ____  _  ___               
          | | | |_   _|_   _|  _ \    |___ \/ |( _ )              
          | |_| | | |   | | | |_) |____ __) | |/ _ \              
          |  _  | | |   | | |  __/_____/ __/| | (_) |             
  ____    |_| |_| |_|   |_|_|_|_ ___  |_____|_|\___/____  ____  _ 
 / ___|  / \      / \     |_   _/ _ \ / _ \| |     |  _ \/ ___|/ |
| |     / _ \    / _ \ _____| || | | | | | | |     | |_) \___ \| |
| |___ / ___ \  / ___ \_____| || |_| | |_| | |___ _|  __/ ___) | |
 \____/_/   \_\/_/   \_\    |_| \___/ \___/|_____(_)_|   |____/|_|

"@

while ($true) {
    Write-Host $asciiBanner -ForegroundColor DarkYellow

    Write-Host "[1] Scan Only (No admin required)" -ForegroundColor Green
    Write-Host "[2] Full Tool (Requires admin privileges)" -ForegroundColor Yellow
    Write-Host "[0] Exit"
    Write-Host ""

    $Choice = Read-Host "Enter a number"
    Write-Host ""

    switch ($Choice) {
        "1" {
            Write-Host "[INFO] Launching Scan Only mode..." -ForegroundColor Green
            Invoke-RestMethod $RepoURL -OutFile $ToolPath 
            & $PS5Path -NoExit -ExecutionPolicy Bypass -File $ToolPath -ScanOnly
            Remove-Item $ToolPath -Force
        }
        "2" {
            Write-Host "[INFO] Launching Full Tool (requires elevation)..." -ForegroundColor Yellow
            try {
                Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "Invoke-RestMethod $RepoURL | Invoke-Expression" -WindowStyle Normal
            }
            catch {
                Write-Host "[ERROR] Could not launch elevated PowerShell. UAC prompt was likely cancelled." -ForegroundColor Red
                Read-Host "Press any key to continue"
            }
        }
        "0" {
            Write-Host "Bye!"
            exit 0
        }
        default {
            break
        }
    }
    Write-Host "`nReturning to menu..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    Clear-Host
}
