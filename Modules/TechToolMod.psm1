# TTGC - Get Info Custom
# TTGM - Get Info
# TTRC - Run Custom
# TTRM - RunScript
#
Function Invoke-TTRMExecuteCommand{
    param($device,$creds,$command)
    $command = [ScriptBlock]::Create($command)
    $result = Invoke-Command -credential $creds -computername $device -ArgumentList $command -ScriptBlock{
        Param($command)
        & $command
    }
    Return $result
}
Function Invoke-TTRMForceInstantRestart{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        shutdown /r /f /t 0
    }
    Return $result
}
Function Invoke-TTRMUninstallFiltered{
    param($device,$creds,$filter)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        (Get-WmiObject -Class Win32_Product | Where-Object{$_.Name -match $filter}).uninstall()
    }
    Return $result
}
Function Invoke-TTRMRestart{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        Restart-Computer -Force
    }
    Return $result
}
Function Add-TTRMAdminForLoggedOnUser{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        Try{
            $user = (Get-WmiObject -Query "select * from win32_process where name='explorer.exe'").getowner().user
        }catch{
            Return "No logged on User"
        }
        Add-LocalGroupMember -Group "Administrators" -member $user | out-Null
        (Get-LocalGroupMember -name "Administrators").name | where {$_ -match $user}
    }
    Return $result
}
# Get Info
Function Get-TTGMLoggedOnUser{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        (Get-WmiObject -Query "select * from win32_process where name='explorer.exe'").getowner().user
    }
    Return $result
}
Function Get-TTGMSerialNumber{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        (Get-WmiObject -Class win32_bios).serialnumber
    }
    Return $result
}
Function Get-TTGMAdminsOnMachine{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        Get-LocalGroupMember -Group "Administrators"
    }
    Return $result
}
Function Get-TTGMBatteryPluggedIn{
    param($device,$creds)
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        Switch ((Get-WmiObject -Class BatteryStatus -Namespace root\wmi -ErrorAction SilentlyContinue).PowerOnLine){
            $true {Write-Output "Battery is plugged in"}
            $false {Write-Output "Battery is NOT plugged in"}
            default {Write-Output "Error"}
        }
    }
    Return $result
}
function Get-TTGMipv4Address{
    param($device,$creds)
    $return = (Test-Connection $device -Count 1 ).IPV4Address.ipaddresstostring
    return $return
}
function Get-TTGMBiosVersion{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        "$((Get-WmiObject -Class Win32_bios).version) $((GET-WMIOBJECT win32_operatingsystem).version)"
    }
    return "Bios Version | $return"
}
function Get-TTGMComputerName{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
         hostname
    }
    return $return
}
function Get-TTGMComputerModel{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        (Get-CimInstance -ClassName Win32_ComputerSystem).model
    }
    return $return
}
function Get-TTGMUptime{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
    $now = get-date
    $time = New-Timespan -start $return -end $now
    
    return "$($time.ToString("ddd' days 'hh' hours 'mm' minutes 'ss' seconds'")) LastLogon: $($return.ToString())"
}
function Get-TTGMArpMacAddress{
    param($device,$creds)
    $return = (get-netneighbor -IPAddress (Test-Connection $device -Count 1 ).IPV4Address.ipaddresstostring).LinkLayerAddress
    return $return
}
function Get-TTGMFreeCDriveSpace{
    param($device,$creds)
    $Space = (Get-WmiObject Win32_LogicalDisk -ComputerName $device -Credential $creds -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace)
    $percent = ($Space.FreeSpace / $Space.size).tostring("P") 
    $bar = "{"
    $bar += "||" * (20 - ([math]::floor([int]($percent.split(".")[0]) / 5)))
    $bar += "_" * ([math]::floor([int]($percent.split(".")[0]) / 5))
    $bar += "} "
    $return =  $bar + $percent + " Free Space"
    return $return  
}
function Get-TTGMos{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        Write-output "$((Get-ComputerInfo).osname) $((GET-WMIOBJECT win32_operatingsystem).version)"
    }
    return $return
}
Function Get-TTGMInstalledApplications{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
            $Applications = @()
            $Applications += get-childitem HKLM:\Software\microsoft\windows\currentVersion\uninstall 
            $Applications += get-childitem HKLM:\Software\wow6432Node\microsoft\windows\currentVersion\uninstall 
            $Applications | foreach {(get-itemproperty $_.pspath).displayname } | sort-object 
        }
        $header = "$($return.count) applications Found.`r`n"
        $return | foreach {$splitreturn = $splitreturn + "$_`r`n"}
        $return = $header + $splitreturn
        return $return
}
Function Get-TTGMFilteredInstalledApplications{
    param($device,$creds,$filter)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
            $Applications = @()
            $Applications += get-childitem HKLM:\Software\microsoft\windows\currentVersion\uninstall 
            $Applications += get-childitem HKLM:\Software\wow6432Node\microsoft\windows\currentVersion\uninstall 
            $Applications | foreach {(get-itemproperty $_.pspath).displayname } | sort-object 
        }
        $return = $return | where {$_ -match $filter}
        #$header = "$($return.count) applications Found.`r`n"
        $return | foreach {$splitreturn = $splitreturn + "$_`r`n"}
        $return = $header + $splitreturn
        return $return
}
Function Get-TTGMFilteredInstalledApplications{
    param($device,$creds,$filter)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
            $Applications = @()
            $Applications += get-childitem HKLM:\Software\microsoft\windows\currentVersion\uninstall 
            $Applications += get-childitem HKLM:\Software\wow6432Node\microsoft\windows\currentVersion\uninstall 
            $Applications | foreach {(get-itemproperty $_.pspath).displayname } | sort-object 
        }
        $return = $return | where {$_ -match $filter}
        #$header = "$($return.count) applications Found.`r`n"
        $return | foreach {$splitreturn = $splitreturn + "$_`r`n"}
        $return = $header + $splitreturn
        return $return
}
function Get-TTGMUsersInUserFolder{
    param($device,$creds)
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock{
        get-childitem "c:\users"
    }
    return $return
}
