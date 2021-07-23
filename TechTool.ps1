[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
Add-Type –assemblyName PresentationFramework

#initial Variables
$logfilelocation = "C:\TechTool\"
$runspaceMonitor = $null
$seeingsfilelocation = "$PSScriptRoot\settings"

[xml]$xaml = Get-Content "$PSScriptRoot\Xaml\main.xaml"
[xml]$xamlinputbox = Get-Content "$PSScriptRoot\Xaml\inputbox.xaml"
[xml]$xamlCustomDeploy = Get-Content "$PSScriptRoot\Xaml\customdeploy.xaml"
[xml]$xamlSettings = Get-Content "$PSScriptRoot\Xaml\settings.xaml"
[xml]$xamlLogBox = Get-Content "$PSScriptRoot\Xaml\LogBox.xaml"
[xml]$xamlCustomgetrun = Get-Content "$PSScriptRoot\Xaml\customgetrun.xaml" 

#Setup Hash, reader and window
$Script:runspaces = New-Object System.Collections.ArrayList   
$syncHash = [hashtable]::Synchronized(@{})
$syncHash.host = $host
$reader = New-Object System.Xml.XmlNodeReader $xaml
$syncHash.window = [Windows.Markup.XamlReader]::Load($reader)
$sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
$runspacepool = [runspacefactory]::CreateRunspacePool(1, 10, $sessionstate, $Host)
$runspacepool.Open() 

#connect Controls
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach {
    $syncHash.($_.Name) = $syncHash.window.FindName($_.Name)
}
$syncHash.content = @()
$syncHash.contentfull = @()
$syncHash.logfilelocation = $logfilelocation

#get creds
$Domaintest = $null
While($Domaintest.name -eq $null){
    $syncHash.creds = Get-Credential -Message "Please enter credentails with domain"
    $Root = "LDAP://" + ([ADSI]'').distinguishedName
    if ($syncHash.creds.getnetworkcredential().domain -ne "" ){
        $Domaintest = New-Object System.DirectoryServices.DirectoryEntry(
            $Root,
            $syncHash.creds.username,
            $syncHash.creds.GetNetworkCredential().password
        )
    }
}

#import Modules
$syncHash.CISModuleLocation = "$PSScriptRoot\Modules\CIS.psm1"
$syncHash.CFModuleLocation = "$PSScriptRoot\Modules\CodeFunctions.psm1"
$syncHash.TTModuleLocation = "$PSScriptRoot\Modules\TechToolMod.psm1"
$syncHash.TTDeployLocation = "$PSScriptRoot\Modules\TechToolDeploy.psm1"

Import-Module $syncHash.CISModuleLocation -force
Import-Module $syncHash.TTModuleLocation -force
Import-Module $syncHash.TTDeployLocation -force
#Import-Module "$PSScriptRoot\Modules\Runspacemonitor.psm1" -force   

$syncHash.codefunctions = {
    Param ($device,$synchash)
    Import-Module $syncHash.CISModuleLocation -force
    Import-Module $syncHash.TTModuleLocation -force
    Import-Module $syncHash.TTDeployLocation -force
    Import-Module $syncHash.CFModuleLocation -force

}


Function Remove-FinishedRunspaceData {
    Foreach($runspace in $runspaces) {
        If ($runspace.Runspace.isCompleted) {
            $runspace.powershell.EndInvoke($runspace.Runspace)
            $runspace.powershell.dispose()
            $runspace.Runspace = $null
            $runspace.powershell = $null                 
        } 
    }
}

Function create-logfilelocation{
    param($logfilelocation)
    if(!(test-path $logfilelocation)){
        New-Item $logfilelocation -ItemType "directory"
    }

}

Function open-file{
    $initialDirectory = "C:\"
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = $initialDirectory
    $OpenFileDialog.Filter = "All Files (*.*)| *.*"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.FileName
}
function Read-Aguments{

    return [Microsoft.VisualBasic.Interaction]::InputBox("Input Arguments", "Please enter any input arguments you require for deployment", "/quiet")
}

function Create-RunspacePool {
    param($syncHash,$code,$device)
    
    $code = $([ScriptBlock]::Create($syncHash.codeFunctions.ToString() + "`n" + '$device = "'+ $device + "`"`n" + $code.ToString())) #fuses our code with the functions code.
    $syncHash.debug = $code
    $powershell = [powershell]::Create().AddScript($code).AddArgument($device).AddArgument($syncHash)
    $powershell.RunspacePool = $runspacepool
    $runspaces.Add([PSCustomObject]@{
        Device = $device
        PowerShell = $powershell
        Runspace = $powershell.BeginInvoke()
    }) | Out-Null 
}



function create-popup{
    param($xaml,$code)
    $inputbox = New-Object System.Xml.XmlNodeReader $xaml
    $inputboxwindow = [Windows.Markup.XamlReader]::Load($inputbox)
    $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach {
        New-Variable  -Name $_.Name -Value $inputboxWindow.FindName($_.Name) -Force
    }
    & $code
    $inputboxwindow.ShowDialog()
}
function New-RunSpaceMonitor{
    param($syncHash)
    
    $code = {
        param($syncHash)
        function Move-ContentToListview{
            param($syncHash)
            $syncHash.contentfull | export-csv "$($syncHash.logfilelocation)\log.csv" -NoTypeInformation
            $lview = [System.Collections.IEnumerable]$syncHash.content
            $syncHash.Window.Dispatcher.invoke(
                [action]{ $syncHash.lvUsers.ItemsSource = $lview }
            )
            $syncHash.lvUsers.ItemsSource.refresh()
        }
        $running = $true
        $syncHash.debugmonitor = $running
        $statusbar = "Initializing"
        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Statusbar.text = $Statusbar})
        while($running -eq $true){
            $running = $false
            Foreach($runspace in $runspaces) {
                If ($runspace.Runspace.isCompleted) {
      
                    #Move-ContentToListview -synchash $synchash
                    $runspace.powershell.EndInvoke($runspace.Runspace)
                    $runspace.powershell.dispose()
                    $runspace.Runspace = $null
                    $runspace.powershell = $null                 
                }else{$running = $true}
            }
            $statusbar = "Tasks: " + (Get-Runspace).count + ' | $runspaces: | ' + $runspaces.count
            $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Statusbar.text = $Statusbar})
            
        }
    }
    $device = 'Monitor'
    $powershell = [powershell]::Create().AddScript($code).AddArgument($syncHash)
    $powershell.RunspacePool = $runspacepool
    $runspaces.Add([PSCustomObject]@{
        Device = $device
        PowerShell = $powershell
        Runspace = $powershell.BeginInvoke()
    }) | Out-Null 

}




function Invoke-LoopHandler{
    param($code)
    #$code.tostring()
    $Acronym = ($code.tostring().split("-")[1]).substring(2,1)

    $code = $code.ToString()
    $commandlist = (get-command $code).parameters.Keys 
    
    $commandlist | foreach {
        if($_ -eq 'filepath'){
            $filebrowser = Get-FileBrowser
            $deploycmd = (Get-InstallLine -FileBrowser $filebrowser).tostring()
            $filepath = $filebrowser.filename
            $code = $code + " -filepath " + $filepath + " -deploycmd " + $deploycmd

        }
        if($_ -ne  'device' -and 
            $_ -ne 'creds' -and
            $_ -ne 'filepath' -and
            $_ -ne 'DeployCMD'){
                $CurrentCommand = [Microsoft.VisualBasic.Interaction]::InputBox("Input $_", "Input $_")
                $code = $code + " -$_ " + $CurrentCommand
        }
    }

    if ($Acronym -eq "R" -or $Acronym -eq "D"){
        $sure = [System.Windows.MessageBox]::Show("The Following Command will be executed " + $code + " Proceed?",'Execute Command','YesNo','Information')
        if ($sure -eq "No"){Return}
    }

   
    $syncHash.lvusers.SelectedItems | foreach {
        Create-RunspacePool -code $([ScriptBlock]::Create('invoke-scriptupdateinformation -command {'+ $code + ' -device $device -creds $syncHash.creds} -device $device')) -synchash $syncHash -device $_.device
    }
    
    #Import-Module "$PSScriptRoot\Modules\Runspacemonitor.psm1" -force    
    New-RunSpaceMonitor -syncHash $syncHash
    
}




function Get-FileBrowser{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = $PSScriptRoot }
    $FileBrowser.Title = "Select file to be deployed"
    $null = $FileBrowser.ShowDialog()
    return $FileBrowser
}
Function Get-InstallLine{
    param($FileBrowser)
    if ($FileBrowser.SafeFileName.Substring($FileBrowser.SafeFileName.Length - 4) -eq ".msi" ){
        $dScript = "msiexec.exe /i `"" + $FileBrowser.SafeFileName + "`" /q"
    }
    if ($FileBrowser.SafeFileName.Substring($FileBrowser.SafeFileName.Length - 4) -eq ".exe" ){
        $dScript = $FileBrowser.SafeFileName + " /s"
    }
    $script = [Microsoft.VisualBasic.Interaction]::InputBox("paste in the install script for the file", "Script", $dScript)
    $dScript = $FileBrowser.SafeFileName
    return $dScript
}
function hide-rowitems{
    param($devices)
    $devices | foreach {
        for($i=0; $i -lt $syncHash.content.count; $i++){
            if($_ -eq $syncHash.content[$i].device){# finds device and updates
                $syncHash.content[$i].removed = $true
            }
        }    
    }
    #Magic
    $newcontent = @()
    $newcontentfull = @()
    for($i=0; $i -lt $syncHash.content.count; $i++){
        if($syncHash.content[$i].removed -ne $true){
            $C=$syncHash.content[$i]
            $CF=$syncHash.contentfull[$i]
            $newcontent += $C
            $newcontentfull += $CF
        }
    }
    $syncHash.contenttemp = $newcontent
    $syncHash.contentfulltemp = $newcontentfull
    #Magic
    $lview = [System.Collections.IEnumerable]$syncHash.contenttemp
    $syncHash.Window.Dispatcher.invoke(
        [action]{ 
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lview)
	    $view.SortDescriptions.Clear()
        $varheader = 'header' + $syncHash.col
	    try{$sortDescription = New-Object System.ComponentModel.SortDescription($syncHash.col, $syncHash.$varheader)}catch{}
    	try{$view.SortDescriptions.Add($sortDescription)}catch{}
        $syncHash.lvUsers.ItemsSource = $lview 
        }
    )

}
function Save-File{
    param([string] $initialDirectory )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "All files (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() |  Out-Null
    return $OpenFileDialog.filename
} 




# Gui Buttons
#############

$syncHash.About.Add_Click({
    [System.Windows.MessageBox]::Show("Posh Hermes - Version 0.1.2021.04.26`r`n`rCreated by Harley Schaeffer`r`n")
})



$sb= {
    $SyncHash.col = $_.OriginalSource.Column.Header
    $varheader = 'header' + $SyncHash.col
	if ($syncHash.$varheader -ne 'Ascending'){$syncHash.$varheader = 'Ascending'}else{$syncHash.$varheader = 'Descending'}
    
	$view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($SyncHash.lvusers.ItemsSource)
	$view.SortDescriptions.Clear()
    

	$sortDescription = New-Object System.ComponentModel.SortDescription($syncHash.col, $syncHash.$varheader)
	$view.SortDescriptions.Add($sortDescription)

}
$evt = [Windows.RoutedEventHandler]$sb
$syncHash.lvusers.AddHandler(
    [System.Windows.Controls.GridViewColumnHeader]::ClickEvent, $evt

    
)




$syncHash.lvUsers.Add_MouseDoubleClick({
    if(!($syncHash.lvUsers.SelectedItems.device -eq $null)){
        $codeinputbox = {
            $device = $syncHash.lvUsers.SelectedItems.device
            $result = [array]::IndexOf( $syncHash.Contentfull.device , $device )
            if($syncHash.Contentfull.log.GetType().baseType.name -eq "Array"){
                $LogBox.Text=$syncHash.Contentfull.log[$result]
            }else{$LogBox.Text=$syncHash.Contentfull.log}
        }
        create-popup -xaml $xamlLogBox -code $codeinputbox
    }
})

$syncHash.CiscoSettings.Add_Click({
    $global:ipofcore = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter the IP of the Core Switch", "Please enter the IP of the Core Switch")
    $global:corecreds = Get-Credential -Message "Creds for Core Switch"
    $global:switchcreds = Get-Credential -Message "Creds for Switches"
})



$syncHash.SettingsMenu.Add_Click({
    $codeinputbox = {
        $inputboxwindow.Add_Loaded({
            $OUSearchbase.Text = $syncHash.Settings.OUSearchbase
        })
        $Save.Add_Click({
            $syncHash.Settings.OUSearchbase = $OUSearchbase.Text
            set-content -Path "$seeingsfilelocation\settings.json" -value ($syncHash.Settings | convertto-Json)
            $inputboxWindow.close()
        })
        $Cancel.Add_Click({
            $inputboxWindow.close()
        })
    }
    create-popup -xaml $xamlSettings -code $codeinputbox


})
$synchash.inputbox.Add_Click({
    $codeinputbox = {
        $inputOK.Add_Click({
            $devices = -split $inputText.Text
            foreach ($device in $devices){
                $SyncHash.content += New-Object psobject -Property @{Device=$device;Information='';Run='';Deployment='';Output='';Removed=$false}
                $SyncHash.contentfull += New-Object psobject -Property @{Device=$device;Information='';Run='';Deployment='';Output='';Removed=$false;Log=''}
            }
            #Magic
            $newcontent = @()
            $newcontentfull = @()
            for($i=0; $i -lt $syncHash.content.count; $i++){
                if($syncHash.content[$i].removed -ne $true){
                    $C=$syncHash.content[$i]
                    $CF=$syncHash.contentfull[$i]
                    $newcontent += $C
                    $newcontentfull += $CF
                }
            }
            $syncHash.contenttemp = $newcontent
            $syncHash.contentfulltemp = $newcontentfull
            #Magic
            $lview = [System.Collections.IEnumerable]$syncHash.contenttemp
            $syncHash.lvUsers.ItemsSource = $lview
            $inputboxWindow.close()
        })
        $FromOU.Add_Click({
            $OU = [Microsoft.VisualBasic.Interaction]::InputBox("Input OU`nNote: Must Have RSAT installed.", "Input OU")
            $inputText.text += (get-adcomputer -SearchBase "OU=$ou,$($syncHash.Settings.OUSearchbase)" -Filter *).name | foreach {$_ + "`r`n"}
        })
        $fromLDAP.Add_Click({
            $LDAPOU = [Microsoft.VisualBasic.Interaction]::InputBox("Input OU`nNote: Must Have RSAT installed.", "Input OU")
            $LDAPRootOU = "OU=$LDAPou,$($syncHash.Settings.OUSearchbase)"
            $LDAPSearcher = New-Object DirectoryServices.DirectorySearcher
            $LDAPSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($LDAPRootOU)")
            $LDAPcomputers = $LDAPSearcher.FindAll() | select 'path'
            $LDAPresult = $LDAPcomputers | foreach {((($_ -split "CN=")[1]) -split ',')[0]}
            $inputText.text += $LDAPresult | foreach {if($_ -ne ''){ $_ + "`r`n"}}
        })
        $UserManagedObjects.Add_Click({
            $UserMan = [Microsoft.VisualBasic.Interaction]::InputBox("Input OU`nNote: Must Have RSAT installed.", "Input OU")
            
            $ManOb = (get-aduser $UserMan -Properties *).managedobjects | foreach {((($_ -split "CN=")[1]) -split ',')[0]}
            
            $inputText.text += $ManOb | foreach {if($_ -ne ''){ $_ + "`r`n"}}
        
        })
        $inputCancel.Add_Click({
            $inputboxWindow.close()
        })
    }
    create-popup -xaml $xamlinputbox -code $codeinputbox

})
$synchash.CreateCustomDeploy.Add_Click({

    $codeinputbox = {
        $CustomDeployAdd.Add_Click({
            $synchash.content = @()
            $devices = -split $inputText.Text
            foreach ($device in $devices){
                $SyncHash.content += New-Object psobject -Property @{Device=$device;Information='Info';Run='Run';Deployment='';Output='Output';Removed=$false}
                $SyncHash.contentfull += New-Object psobject -Property @{Device=$device;Information='Info';Run='Run';Deployment='';Output='Output';Removed=$false;Log=''}
            }
            $lview = [System.Collections.IEnumerable]$syncHash.content
            $syncHash.lvUsers.ItemsSource = $lview
            $inputboxWindow.close()
        })
        $CustomDeployCancel.Add_Click({
            $inputboxWindow.close()
        })
        $CustomDeployRemove.Add_Click({
            $inputboxWindow.close()
        })
    }
    create-popup -xaml $xamlCustomDeploy -code $codeinputbox

})
$synchash.CreateCustomgetinfo.Add_Click({

    $codepopup = {
        Import-Module $syncHash.CISModuleLocation -force
        $SyncHash.customgetcontent = @()
        $TTMCommandnames = (get-command -Module CIS).name
        $TTMCommandnames | foreach {
            if ($_.contains("-TTGC")){
                $varname = $_.replace("TTGC",'').split("-")[1] -csplit '(?=[A-Z])' -ne '' -join ' '
                $varScriptBlock = (Get-Command $_).ScriptBlock
                $SyncHash.customgetcontent += New-Object psobject -Property @{GetInformation=$varname;Scriptblock=$varScriptBlock}
            }
        }
        $lvget.add_MouseLeftButtonUp({
            $GetRunscriptName.text = $SyncHash.customgetcontent.getinformation[$lvget.selectedindex]
            $fullscriptblock = $SyncHash.customgetcontent.Scriptblock[$lvget.selectedindex]
            $shortscriptblock = $fullscriptblock -split '$scriptblock = {'
            $GetRunscript.text = $shortscriptblock
        
        })
        
        $CustomRunAdd.add_Click({
            $scriptName.text = 'Add'
        
        })
        
        
        
        $lview = [System.Collections.IEnumerable]$SyncHash.customgetcontent
        $lvget.ItemsSource = $lview
        
        <#
        $CustomDeployAdd.Add_Click({
            $synchash.content = @()
            $devices = -split $inputText.Text
            foreach ($device in $devices){
                $SyncHash.content += New-Object psobject -Property @{Device=$device;Information='Info';Run='Run';Deployment='';Output='Output';Removed=$false}
                $SyncHash.contentfull += New-Object psobject -Property @{Device=$device;Information='Info';Run='Run';Deployment='';Output='Output';Removed=$false;Log=''}
            }
            $lview = [System.Collections.IEnumerable]$syncHash.content
            $syncHash.lvUsers.ItemsSource = $lview
            $inputboxWindow.close()
        })
        $CustomDeployCancel.Add_Click({
            $inputboxWindow.close()
        })
        $CustomDeployRemove.Add_Click({
            $inputboxWindow.close()
        })
        #>
    }
    
    create-popup -xaml $xamlCustomgetrun -code $codepopup


})


$syncHash.software.Add_Click({

    $code = {Invoke-TTDMDeploySoftware}
    Invoke-loopHandler -code $code
})




$syncHash.export.Add_Click({
    $exportfilelocation = save-file
    $syncHash.content | export-csv $exportfilelocation -NoTypeInformation
})



create-logfilelocation $syncHash.logfilelocation

### Imports CIS
function Create-menuitems{
    Param($Acronym,$menuname)
    if ($_.contains("-$Acronym")){
        $varName = $_ -replace("-","")
        $syncHash.$varName = New-Object System.Windows.Controls.MenuItem
        $syncHash.$varName.name = $_.split("-")[1].replace("$Acronym",'')
        $syncHash.$varName.header = $_.split("-")[1].replace("$Acronym",'') -csplit '(?=[A-Z])' -ne '' -join ' '
        $syncHash.window.FindName("$menuname").addchild($syncHash.$varName)
        $code = $_
        $syncHash.$varName.Add_Click([ScriptBlock]::Create("Invoke-loopHandler -code " + $code))
        #))#.GetNewClosure())#GetNewClosure makes it so $code stays static at the time that the script is read. Or else if fucks it and just uses the last thing $code is.
    }

}
# TTGC - Get Info Custom
# TTGM - Get Info
# TTRC - Run Custom
# TTRM - Run 

$TTMCommandnames = (get-command -Module TechToolMod).name
$TTMCommandnames | foreach {
    
    Create-menuitems -Acronym 'TTGM' -menuname 'GetInfo'
    Create-menuitems -Acronym 'TTRM' -menuname 'RunScript'
}
$CISCommandnames = (get-command -Module cis).name
$CISCommandnames | foreach {
    Create-menuitems -Acronym 'TTGC' -menuname 'CustomGetInfo'
    Create-menuitems -Acronym 'TTRC' -menuname 'CustomRun'
}

#setup settings

if (!(Test-Path -Path "$seeingsfilelocation\settings.json")){
    set-content -Path "$seeingsfilelocation\settings.json" -value (@{OUSearchbase=''} | convertto-Json)
    $syncHash.settings = get-content -Path "$seeingsfilelocation\settings.json" | ConvertFrom-Json
    write-output "Creating New Settings File"
}else{
    $syncHash.settings = get-content -Path "$seeingsfilelocation\settings.json" | ConvertFrom-Json
    Write-output "Loading Settins"
}


$syncHash.window.Add_KeyDown({
    if($_.Key -eq "Delete"){
        hide-rowitems -devices $syncHash.lvUsers.SelectedItems.device
    }
})




$syncHash.window.ShowDialog()



Foreach($runspace in $runspaces) {
        $runspace.powershell.EndInvoke($runspace.Runspace)
        $runspace.powershell.dispose()
        $runspace.Runspace = $null
        $runspace.powershell = $null                 
}
$Runspacepool.Close()
$Runspacepool.Dispose()

