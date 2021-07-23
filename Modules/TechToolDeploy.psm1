Function Invoke-TTDMDeploySoftware{
    param($device,$creds,$filepath,$deploycmd)
    New-PSDrive -Name mDrive -PSProvider FileSystem -Root "\\$device\C$" -Credential $creds | Out-Null
    if(!(Test-Path -Path "mDrive:\temp")){
        New-Item -Path "mDrive:\temp" -ItemType directory 
    }
    $result = @()
    if(Test-Path -Path "mDrive:\temp"){
        $result += Copy-Item $filepath "mDrive:\temp\" -Force 
        $result += Invoke-Command -ComputerName $device -Credential $creds -ArgumentList $deploycmd -ScriptBlock {
            Param ($deploycmd)
            & cd c:\temp\
            & cmd /c $deploycmd
            & cmd /c echo Exit Code: %errorlevel%
        }
        Remove-PSDrive -Name mDrive
    }else{$result += "Not able to map drive. Check to see if device is reachable."}
    return $result
}
