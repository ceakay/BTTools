$PSScriptRoot
cd $PSScriptRoot
$TagFile = Join-Path -Path $PSScriptRoot -ChildPath "TagConfig.csv"
$TagFile
    #Parse TagConfig.csv
    $TagFile = Join-Path -Path $PSScriptRoot -ChildPath "TagConfig.csv"
    $CSVRawObject = Import-Csv -path $TagFile
    $KeysList = $($CSVRawObject | Get-Member -MemberType Properties).Name
    $KeysObject = [pscustomobject]@{}
    write-progress -activity 'Building Faction Groups'
    foreach ($Key in $KeysList) {
        Add-Member -InputObject $KeysObject -MemberType NoteProperty -Name $Key -Value @()
        $KeysObject.$Key = $($CSVRawObject | select -ExpandProperty $Key)
        $KeysObject.$Key = $($GroupObject.$BuildGroup | Where-Object {$_})
    }