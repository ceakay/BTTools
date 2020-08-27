#This parses ChassDef and MechDef for info
#
#

#SET FUNCTIONS
###
#makearray function
    #args: delimeter, input
function makearray {
    $array = @($args[1] -split "$($args[0])")
    return $array
}

#data chopper function
    #args: delimiter, position, input
function datachop {
    $array = @($args[2] -split "$($args[0])")    
    return $array[$args[1]]
}

#SET CONSTANTS
###
#RogueTech Dir (Where RTLauncher exists)
$RTroot = "D:\\RogueTech"
#Script Root
$RTScriptroot = "D:\\RogueTech\\WikiGenerators"
cd $RTScriptroot
#cache path
$CacheRoot = "$RTroot\\RtlCache\\RtCache"
#stringarray - factions - sort by display alpha
    #fuck this. build it from \RogueTech Core\Faction.json
$FactionFile = "$CacheRoot\\RogueTech Core\\Faction.json"

#save file
$MechsFile = "$RTScriptroot\\Outputs\\MechListTable.json"
#build faction groups. data incomplete (no periphery tags exist, factions can be containered in multiple groups), create from human readable CSV.
$GroupingFile = "$RTScriptroot\\Inputs\\FactionGrouping.csv"
#Tag input
$SpecialFile = "$RTScriptroot\\Inputs\\Special.csv"
#weight file
$ClassFile = "$RTScriptroot\\Inputs\\Class.csv"
#string - conflictfile
$conflictfile = "$RTScriptroot\\Outputs\\conflict.csv"

#TempMove stuff
$TempMoveFile = "$RTScriptroot\\Outputs\\MexPagesList.txt"
$TempMoveArray = @(Get-Content $TempMoveFile)
$TempMovePWBFile = "$RTScriptroot\\pairs.txt"
$TempMovePWBUTF8 = "$RTScriptroot\\pairs.utf8"
try {Remove-Item $TempMovePWBFile} catch {}

foreach ($TempMoveItem in $TempMoveArray) {
    "{{-start-}}`r`n'''$TempMoveItem'''`r`n#REDIRECT [[Mechs/$TempMoveItem]]`r`n{{-stop-}}`r`n" >> $TempMovePWBFile
}

Get-Content $TempMovePWBFile | Set-Content -Encoding UTF8 $TempMovePWBUTF8

py $PWBRoot\\pwb.py login
cls
cd $RTScriptroot
py $PWBRoot\\pwb.py pagefromfile -file:pairs.utf8 -notitle -force -pt:0
cls