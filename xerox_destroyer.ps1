cls
#Requires -RunAsAdministrator
$ErrorActionPreference = "stop"
<#
.SYNOPSIS
Remove ghost Xerox printers created by the Xerox Print Experience app

.DESCRIPTION
This is an issue created by the Xerox Print Expereice app that will duplicate every printer installed on the pc and duplicate them based off the number of profiles installed on the system. 
IE if there are 2 printers installed on the system and there are 4 user profiles each person will have 8 printers show up as being able to be selected.
This however is not the case and if the user selects the ghost printer nothing will work, the PC will also display printer notifications each time one of these ghost printers is being installed, which can be extreamly annoying to people.  
If the user removes the printers manually on the next reboot or GPO refresh the printers will install again by themselves in a seemly endless loop.
This script will remove all ghost printers for all user profiles. However if the Xerox Print Experience app is reinstalled in the future the ghost printers will appear again.

.NOTES
Needs to be run as administrator
#>

## Check for log location
$loglocation = "$env:programdata\Xerox_Destroyer"

if (!(test-path $loglocation)) {
    new-item -Name "Xerox_Destroyer" -ItemType Directory -Path $env:programdata -Force | Out-Null
}

function LogOutput {
    param (
        [string]
        $message
    )

    ## Setup logging
    $date = (get-date).tostring("MM/dd/yyy hh:mm tt")
    add-content $LogLocation\XeroxClean.log "[$date]: $message" 
}

function Cleanup {
    ## Generate clean up script
    $remove = 
@'
    $loglocation = "$env:programdata\Xerox_Destroyer"
    function LogOutput {
        param (
            [string]
            $message
        )

        ## Setup logging
        $date = (get-date).tostring("MM/dd/yyy hh:mm tt")
        add-content $LogLocation\XeroxClean.log "[$date]: $message" 
    }

    $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\PRINTENUM\*"
    $xprinters = gci -path $path | get-itemproperty

    try {
        foreach ($printer in $xprinters) {
            if ($printer.mfg -like "*Xerox*") {
                remove-item -path $printer.PSPath -force -recurse 
                LogOutput -message "Successfully deleted printenum entries for $($printer.friendlyname)"
            }
        }
    }
    catch {
        LogOutput -message "Failed to delete printenum entries, printers will not be removed for all users, try to rerun script to remove reg entries."
    }
'@

    write-host "Ghost registry cleanup: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Cleaning ghost reg entries."

    ## Check to see if clean up script already exists if not generate script
    $clean = "$env:ProgramData\Xerox_Destroyer\cleanup.ps1"

    if (!(test-path $clean)) {
        $remove | out-file -FilePath $clean
    }

    ## Check to see if scheduled task is created, if not create
    $task = get-scheduledtask -taskname "Xerox Cleanup" -ErrorAction SilentlyContinue

    if (!($task)) {
        $User = "NT AUTHORITY\SYSTEM"
        $Action = New-ScheduledTaskAction -Execute "Powershell" -Argument "-executionpolicy bypass -file $env:ProgramData\Xerox_Destroyer\cleanup.ps1"
        Register-ScheduledTask -TaskName "Xerox Cleanup" -Action $Action -User $User | Out-Null
    
        try {
            Start-ScheduledTask -TaskName "Xerox Cleanup" 
			sleep -seconds 15
            write-host "Success" -fore green
            LogOutput -message "Successfully started cleanup task"
        }
        catch {
            write-host "Fail" -fore red
            LogOutput -message $($_.exception.message)
        }      
    }
}

function AltCleanup {

    ## Generate clean up script
    $altremove = 
@'  
    $loglocation = "$env:programdata\Xerox_Destroyer"
    function LogOutput {
        param (
            [string]
            $message
        )

        ## Setup logging
        $date = (get-date).tostring("MM/dd/yyy hh:mm tt")
        add-content $LogLocation\XeroxClean.log "[$date]: $message" 
    }

    $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\DRIVERENUM\*Xerox*"
    $xprinters = gci -path $path | get-itemproperty -Name DeviceDesc

    try {
        foreach ($printer in $xprinters) {
            if ($printer.DeviceDesc -like "*Xerox*") {
                remove-item -path $printer.PSPath -force -recurse 
                LogOutput -messasge "Successfully deleted driverenum entries for $($printer.devicedesc)"
            }
        }
    }    
    catch {
        LogOutput -messasge "Failed to delete driverenum entries, printers will not be removed for all users, try to rerun script to remove reg entries"
    }
'@

    write-host "Alternate method deployed: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Alt cleanup method deployed."

    ## Check to see if clean up script already exists if not generate script
    $clean = "$env:ProgramData\Xerox_Destroyer\altcleanup.ps1"

    if (!(test-path $clean)) {
        $altremove | out-file -FilePath $clean
    }
    
    ## Check to see if scheduled task is created, if not create
    $task = get-scheduledtask -taskname "Xerox Alt Cleanup" -ErrorAction SilentlyContinue

    if (!($task)) {
        $User = "NT AUTHORITY\SYSTEM"
        $Action = New-ScheduledTaskAction -Execute "Powershell" -Argument "-executionpolicy bypass -file $env:ProgramData\Xerox_Destroyer\altcleanup.ps1"
        Register-ScheduledTask -TaskName "Xerox Alt Cleanup" -Action $Action -User $User | Out-Null
        
        try {
            Start-ScheduledTask -TaskName "Xerox Alt Cleanup" 
            sleep -seconds 15
            write-host "Success" -fore green
            LogOutput -message "Successfully started alt cleanup task."
        }
        catch {
            write-host "Fail" -fore red
            LogOutput -message $($_.exception.message)
        }      
    }
}

function RemoveDriver {
    write-host "Driver removal: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Cleaning printer drivers."

    $drvindx = @()
    $pnp = pnputil -e
    $i = 0

    $pnp | foreach { 
        if ($_ -like "*xerox*") {
            $drvindx += ($i - 1)
        }
        $i++
    }

    $drv = foreach ($indx in $drvindx) {
        $pnp[$indx].substring(
            $pnp[$indx].indexof("o"),
            $pnp[$indx].indexof("f") + 1 - $pnp[$indx].indexof("o")
        )
    }

    $pnpextcode = @()

    foreach ($drvoem in $drv) {
        pnputil -f -d $($drvoem) | out-null
        
        $extcode = $LASTEXITCODE
        $pnpextcode += $extcode
    }

    ## Check to see if drivers were removed
    if ($pnpextcode | ? { $_ -gt 0 }) {
        write-host "Fail" -fore red
        LogOutput -message "Error removing printer drivers. $($_.exception.message)" 
    } else {
        write-host "Success" -fore green
        LogOutput -message "Successfully removed printer drivers."
    }
}

## Log user running script for audit purposes
LogOutput -message "Script was ran by user $env:USERNAME on $env:computername"

## Define registry locations
$path1 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider"
$path2 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\V4 Connections\*"
$path3 = "HKCU:\Printers\*"
$path4 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections\*"
$path5 = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PrinterPorts\"

$intro = @'
             __   _____________ _______   __ ______ _____ _____ ___________ _______   _____________ 
             \ \ / /  ___| ___ \  _  \ \ / / |  _  \  ___/  ___|_   _| ___ \  _  \ \ / /  ___| ___ \
              \ V /| |__ | |_/ / | | |\ V /  | | | | |__ \ `--.  | | | |_/ / | | |\ V /| |__ | |_/ /
              /   \|  __||    /| | | |/   \  | | | |  __| `--. \ | | |    /| | | | \ / |  __||    / 
             / /^\ \ |___| |\ \\ \_/ / /^\ \ | |/ /| |___/\__/ / | | | |\ \\ \_/ / | | | |___| |\ \ 
             \/   \|____/\_| \_|\___/\/   \/ |___/ \____/\____/  \_/ \_| \_|\___/  \_/ \____/\_| \_|
             ---------------------------------------------------------------------------------------
                                               Destroyer of Xerox                                   
             ---------------------------------------------------------------------------------------
'@

write-host $intro
write-host
write-host "**ATTENTION** Make sure to check printers are removed from Devices and Printers after running this script..." -ForegroundColor Red
write-host "Log file saved to C:\ProgramData\Xerox_Destroyer check log for any errors after running script..." -foregroundcolor cyan
write-host
write-host 'Press [c] to continue script, anyother key to exit...' -foregroundcolor yellow
$answer = $host.UI.RawUI.ReadKey("noecho, includekeydown")

if ($answer.character -eq "c") {

    write-host "`nRemoving printers: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Removing all installed printers."

    try {
        get-printer | ? { $_.drivername -like "*xerox*" } | remove-printer  
        write-host "Success" -fore green
        LogOutput -message "Successfully removed printers."
    }
    catch {
        write-host "Fail" -fore red
        LogOutput -message "Error removing printers. $($_.exception.message)"
    }

    write-host "Stopping print spooler: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Stopping print spooler."

    try {
        stop-service -name Spooler -Force
        write-host "Success" -fore green
        LogOutput -message "Successfully stopped print spooler."
    }
    catch {
        write-host "Fail" -fore red
        LogOutput -message "Error stopping print spooler. $($_.exception.message)" 
    }

    write-host "Removing registry entries: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Removing registry files."  
    
    try {
        remove-item -path $path1 -recurse -confirm:$false -force 
        remove-item -path $path2 -recurse -confirm:$false -force 
        remove-item -path $path3 -recurse -confirm:$false -force 
        remove-item -path $path4 -recurse -confirm:$false -force 
        remove-item -path $path5 -recurse -confirm:$false -force 
                
        write-host "Success" -fore green
        LogOutput -message "Successfully removed registry entries."
    }
    catch {
        write-host "Fail" -fore red
        LogOutput -message "Failed to remove registry entries. $($_.exception.message)"
    }
    
    write-host "Removing Xerox Print Experience: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Removing Xerox Print Experience."

    try {
        Get-AppPackage | ? { $_.name -like "*xerox*" } | Remove-AppPackage 
        (Get-WmiObject win32_product | ? { $_.vendor -like "*xerox*" }).uninstall

        write-host "Success" -fore green
        LogOutput -message "Successfully removed Xerox Print Experience."
    }
    catch {
        write-host "Fail" -fore red
        LogOutput -message "Failed to uninstall Xerox Print Experience. $($_.exception.message)"
    }

    ## Run funciton to clean ghost printer registry keys
    Cleanup

    ## Run function to uninstall printer drivers
    RemoveDriver

    ## Check for driver removal
    write-host "Verifying driver removal: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Verifying driver removal."

    $drvchk = test-path -path HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\driverENUM\*xerox*

    switch ($drvchk) {
        $false { write-host "Success" -fore green; LogOutput -message "Verify complete." }
        $true { write-host "Fail" -fore red; LogOutput -message "Verifying failed, drivers still remain." }
    }

    ## If verification failed deploy alt removal method
    if ($drvchk) {
        AltCleanup
    }

    ## Clean up
    write-host "Cleaning up: " -NoNewline
    sleep -seconds 2
    LogOutput -message "Performing cleanup."

    try {
        Unregister-ScheduledTask -TaskName "Xerox Cleanup" -confirm:$false
        remove-item "$env:ProgramData\Xerox_Destroyer\cleanup.ps1" -confirm:$false -force
        write-host "Success" -fore green
        LogOutput -message "Successfully completed cleanup task."
    }
    catch {
        write-host "Fail" -fore red
        LogOutput -message $($_.exception.message)
    }
    
    if ($drvchk) {
        write-host "Cleaning up alt tasks: " -NoNewline
        sleep -seconds 2
        LogOutput -message "Performing cleanup of alt tasks."

        try {
            Unregister-ScheduledTask -TaskName "Xerox Alt Cleanup" -confirm:$false
            remove-item "$env:ProgramData\Xerox_Destroyer\altcleanup.ps1" -confirm:$false -force
            write-host "Success" -fore green
            LogOutput -message "Successfully completed cleanup of alt task."
        }
        catch {
            write-host "Fail" -fore red
            LogOutput -message $($_.exception.message)
        }
    }

    ## Ask user to restart
    write-host "`nIt is recommended at this point to restart the PC" -foregroundcolor cyan
    $answer = read-host "Do you want to restart this PC? (y,n)"
    while('y','yes','n','no' -notcontains $answer){
        $answer = read-host "Do you want to restart this PC? (y,n)"
    }

    if ($answer -eq 'y' -or $answer -eq 'yes'){
        LogOutput -message "Restarting PC" 
        write-host "`nRegistry entries have been removed, after restart remember to check printer(s) to make sure they are removed" -foregroundcolor yellow

        ## Initiate countdown
        for ($i = 60; $i -gt 0; $i--) {
            write-host "`rPC will reboot in $i seconds..." -NoNewline -fore yellow
            sleep -seconds 1
        }
        restart-computer
    }

    ## If user does not want to restart start print spooler and refresh printer GPO
    if ($answer -eq 'n' -or $answer -eq 'no'){
        write-host "`nIt is recommended to restart this PC as soon as possible to remove ghost printers from PC`n" -ForegroundColor Red    
        LogOutput -message "PC was not restarted it is recommended to restart the PC as soon as possible" 
        
        write-host "Starting print spooler: " -NoNewline
        sleep -seconds 2
        LogOutput -message "Starting print spooler."

        try {
            start-service -name Spooler
            write-host "Success" -fore green
            LogOutput -message "Successfully started print spooler."
        }
        catch {
            write-host "Fail" -fore red
            LogOutput -message "Error starting print spooler. $($_.exception.message)" 
        }
        
        write-host "Refreshing printer GPO: " -NoNewline
        sleep -seconds 2
        LogOutput -message "Refreshing printer GPO."
        gpupdate /force | out-null
        write-host "Success" -fore green
        sleep -seconds 2
    
        write-host "`nProcess is now complete, remember to check printer(s) to make sure they are removed" -foregroundcolor yellow
    }
}
