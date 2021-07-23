

function update-ListView{
    param($device,$result,$output,$column,[switch]$UpdateOnly)
    if ($syncHash.contentfull -eq $null){$synchash.contentfull = $synchash.content}
    $Date="Date: $(get-date -Format "MM/dd/yy hh:mm:ss")`r`n"
    for($i=0; $i -lt $syncHash.content.count; $i++){
        if($device -eq $syncHash.content[$i].device){# finds device and updates
            if (!($UpdateOnly)){
                $syncHash.content[$i].$column = $result.split("`r`n")[0]
                $syncHash.contentfull[$i].$column =  $date + $result + "`r`n" + $syncHash.contentfull[$i].$column
            }
            if ($syncHash.content[$i].output -ne $null){
                $syncHash.content[$i].output = $output
                $syncHash.contentfull[$i].output = $date + $output + "`r`n" + $syncHash.contentfull[$i].output
            }
            $syncHash.contentfull[$i].log = $syncHash.contentfull[$i].$column + $syncHash.contentfull[$i].output #replaced contentfull with content
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
    
    



    
    $syncHash.contentfulltemp | export-csv "$($syncHash.logfilelocation)\log.csv" -NoTypeInformation
    $lview = [System.Collections.IEnumerable]$syncHash.contenttemp

    
	

    $syncHash.Window.Dispatcher.invoke(
        [action]{ 
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lview)
	    $view.SortDescriptions.Clear()
        $varheader = 'header' + $syncHash.col
	    $sortDescription = New-Object System.ComponentModel.SortDescription($syncHash.col, $syncHash.$varheader)
    	$view.SortDescriptions.Add($sortDescription)
        $syncHash.lvUsers.ItemsSource = $lview 
        }
    )




    <#
    $syncHash.Window.Dispatcher.invoke(
        [action]{ $syncHash.lvUsers.ItemsSource[1].run = 'test8' }
    )
    #>

}
function invoke-scriptupdateinformation{
    param($command,$device)
    update-ListView -device $device -UpdateOnly -output "running $command"
    Switch (($command.tostring().split("-")[1]).substring(2,1)){
        G {$column = "Information"}
        R {$column = "Run"}
        D {$column = "Deployment"}
        default {$column = "Information"}
    }
        

    if(Test-Connection $device -count 1 -quiet){
        $result = & $command
        if($result -eq $null){$result = 'No Results'}
        update-ListView -device $device -result $result -output "Completed $command" -Column $Column
    }else{
        update-ListView -device $device -result ('Offline' + $result) -output "Offline" -Column $Column
    }
}