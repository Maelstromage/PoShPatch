
# TTGC - Get Info Custom
# TTGM - Get Info
# TTRC - Run Custom

# Get Custom Info



Function Get-TTGCDellCommandVersion{
    param($device,$creds)
    $scriptblock = {
        $DCU = Get-WmiObject -Class Win32_Product | where name -match "Dell Command"
        Write-Output "$(($DCU).name) $(($DCU).version)"
    }
    $return = Invoke-Command -credential $creds -computername $device -ScriptBlock $scriptblock
    return $return
}
Function Get-TTGCOsFromActiveDirectory{
    param($device,$creds)
    $OS = get-adcomputer $device -Properties operatingSystem, OperatingSystemServicePack, OperatingSystemVersion
    $return = "$($OS.operatingSystem) $($OS.operatingSystemServicePack) $($OS.operatingSystemVersion) "
    return $return
}
Function Get-TTGCManagedBy{
    param($device,$creds)
    $computer = get-adcomputer $device -Properties Managedby
    $return = $computer.managedby
    return $return
}

function Get-TTGCM402nPrinterPublicName{

    param($device,$creds)
    $wait = 5
    $ie = new-object -com "InternetExplorer.Application"
    sleep $wait
    $ie.Navigate("http://$device/set_config_networkSNMP.html?tab=Networking&menu=NetSNMP")
    $ie.Visible = $false
    sleep $wait
    $doc = $ie.Document
    
    $SCN = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'SetCommunityName'}
    $return = $SCN.value 
    sleep $wait
    $ie.quit()
    return $return

}


# Invoke Run Command
function Invoke-TTRCPM43PrinerPublicFix{
    param($device,$creds,$NewCommunityName)
    $wait = 5
    $ie = new-object -com "InternetExplorer.Application"
    sleep $wait
    $ie.Navigate("http://$device/configure/edit.lua?nodeid=69206042&nodename=SNMP&headnodename=Network%20Services&nodetype=9")
    $ie.Visible = $true
    sleep $wait
    $doc = $ie.Document
    $tb1 = $doc.IHTMLDocument3_getElementById("username")
    $tb1.value = "itadmin"
    $tb2 = $doc.IHTMLDocument3_getElementById("userpassword")
    $tb2.value = "pass"
    $bt = $doc.IHTMLDocument3_getElementById("login")
    $bt.click()
    sleep $wait
    $ie.Navigate("http://$device/configure/edit.lua?nodeid=69206042&nodename=SNMP&headnodename=Network%20Services&nodetype=9")
    sleep $wait
    $doc2 = $ie.Document
    sleep $wait
    $publicboxes = $doc2.IHTMLDocument3_getElementsByTagName('input') | Where-Object {$_.value -eq 'public'}
    foreach ($publicbox in $publicboxes){
        $publicbox.value = $NewCommunityName
    }
    sleep $wait
    $savebt = $doc2.IHTMLDocument3_getElementsByTagName('input') | Where-Object {$_.value -eq 'save'}
    $savebt.disabled = $false
    sleep $wait
    $savebt.click()
    sleep $wait
    sleep $wait
    $ie.quit()
    sleep $wait
}

function Invoke-TTRCM402nPrinterPublicFix{
    param($device,$creds,$NewCommunityName)
    $wait = 5
    $ie = new-object -com "InternetExplorer.Application"
    sleep $wait
    $ie.Navigate("http://$device/set_config_networkSNMP.html?tab=Networking&menu=NetSNMP")
    $ie.Visible = $false
    sleep $wait
    $doc = $ie.Document
    
    $SCN = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'SetCommunityName'}
    $SCN.value = $NewCommunityName
    $CSCN = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'ConfirmSetCommunityName'}
    $CSCN.value = $NewCommunityName
    $GCN = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'GetCommunityName'}
    $GCN.value = $NewCommunityName
    $CGCN = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'ConfirmGetCommunityName'}
    $CGCN.value = $NewCommunityName
    $return = $SCN.value
   
    sleep $wait
    $checkbox = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'DisableCommunityPublic'}
    $checkbox.checked = $true

    sleep $wait
    $bt = $doc.IHTMLDocument3_getElementsByTagName("input") | Where-Object {$_.name -eq 'apply_button'}
    $bt.click()

    sleep $wait
    $ie.quit()
    return $return
}

function Invoke-TTRCTeamViewerSession{
    param($device,$creds)
    $scriptblock = {
        (GP registry::HKLM\SOFTWARE\WOW6432Node\TeamViewer\ ClientID).ClientID
    }
    $TVRemoteRegKey = Invoke-Command -credential $creds -computername $device -ScriptBlock $scriptblock
    $result = cmd /c "C:\Program Files (x86)\TeamViewer\TeamViewer.exe" -i $TVRemoteRegKey
    Return $null
}


Function Invoke-TTRCDellCommandBiosUpdate{
    param($device,$creds)
    $scriptblock = {
        & cmd /c "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe" /applyupdates -silent -reboot=enable
    }
    $result = Invoke-Command -credential $creds -computername $device -ScriptBlock $scriptblock
    Return $result
}


Function Invoke-TTRCAdminAccess{
    param($device,$creds,$user)
    $scriptblock = {
        param($user)
        net localgroup administrators /add $user
    }
    $result = Invoke-Command -credential $creds -computername $device -argumentList $user -ScriptBlock $scriptblock
    Return $result
}
