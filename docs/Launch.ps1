#==============================================================#
#                  CAA-Launcher.ps1 (menu)                     #
#==============================================================#
$RepoURL = "https://raw.githubusercontent.com/HTTP-218/Endpoint_Verification/dev/CAA-Tool.ps1"
$PS5Path  = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$ToolPath = Join-Path $env:TEMP "CAA-Tool.ps1"
Invoke-RestMethod $RepoURL -OutFile $ToolPath 

$asciiBanner = @"


                ██╗  ██╗████████╗████████╗██████╗       ██████╗  ██╗ █████╗          
                ██║  ██║╚══██╔══╝╚══██╔══╝██╔══██╗      ╚════██╗███║██╔══██╗         
                ███████║   ██║      ██║   ██████╔╝█████╗ █████╔╝╚██║╚█████╔╝         
                ██╔══██║   ██║      ██║   ██╔═══╝ ╚════╝██╔═══╝  ██║██╔══██╗         
                ██║  ██║   ██║      ██║   ██║           ███████╗ ██║╚█████╔╝         
                ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝           ╚══════╝ ╚═╝ ╚════╝          
                                                                                     
 ██████╗ █████╗  █████╗    ████████╗ ██████╗  ██████╗ ██╗        ██████╗ ███████╗ ██╗
██╔════╝██╔══██╗██╔══██╗   ╚══██╔══╝██╔═══██╗██╔═══██╗██║        ██╔══██╗██╔════╝███║
██║     ███████║███████║█████╗██║   ██║   ██║██║   ██║██║        ██████╔╝███████╗╚██║
██║     ██╔══██║██╔══██║╚════╝██║   ██║   ██║██║   ██║██║        ██╔═══╝ ╚════██║ ██║
╚██████╗██║  ██║██║  ██║      ██║   ╚██████╔╝╚██████╔╝███████╗██╗██║     ███████║ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝╚═╝     ╚══════╝ ╚═╝


"@
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
        $Command = "-Command & '$ToolPath' -ScanOnly"
        $Process = Start-Process $PS5Path -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", $Command -WindowStyle Normal -PassThru
        $Process.WaitForExit()
        Remove-Item $ToolPath -Force
    }
    "2" {
        Write-Host "[INFO] Launching Full Tool (requires elevation)..." -ForegroundColor Yellow
        try {
            Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "Invoke-RestMethod $RepoURL | Invoke-Expression" -WindowStyle Normal
        }
        catch {
            Write-Host "[ERROR] Could not launch elevated PowerShell. UAC prompt was likely cancelled." -ForegroundColor Red
            Read-Host "Press any key to exit"
            exit 1
        }
    }
    "0" {
        Write-Host "Bye!"
        exit 0
    }
    default {
        Write-Host "[ERROR] Invalid selection. Please run the script again." -ForegroundColor Red
        Read-Host "Press any key to exit"
        exit 1
    }
}
