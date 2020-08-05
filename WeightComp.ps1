#SET CONSTANTS
###
#RogueTech Dir (Where RTLauncher exists)
$RTroot = "D:\\RogueTech"
#Script Root
$RTScriptroot = "D:\\RogueTech\\WikiGenerators"
cd $RTScriptroot
#cache path
$CacheRoot = "$RTroot\\RtlCache\\RtCache"

#Declare class weights hash
$ClassWeights = @{
    unit_light = "LIGHT"
    unit_medium = "MEDIUM"
    unit_heavy = "HEAVY"
    unit_assault = "ASSAULT"
}

$MDefFileObjectList = @(Get-ChildItem $CacheRoot -Recurse -Filter "mechdef*.json")

$CSV = "D:\weights.csv"

'Mech,Error' > $CSV

foreach ($MDefFileObject in $MDefFileObjectList) {
    #setup CDef and MDef objects
    $filePathMDef = $MDefFileObject.VersionInfo.FileName
    $fileNameMDef = $MDefFileObject.Name
    $FileObjectModRoot = "$($MDefFileObject.DirectoryName)\\.."
    try {$MDefObject = ConvertFrom-Json $(Get-Content $filePathMDef -raw)} catch {Write-Host $filePathMDef}
    $fileNameCDef = "$($MDefObject.ChassisID).json"
    $CDefFileObject = Get-ChildItem $FileObjectModRoot -Recurse -Filter "$fileNameCDef"
    #if not found in modroot, try everything
    if (!$CDefFileObject) {
        try {$CDefFileObject = Get-ChildItem $CacheRoot -Recurse -Filter "$fileNameCDef"} catch {Write-Host $fileNameCDef}
    }
    $filePathCDef = $CDefFileObject.VersionInfo.FileName
    try {$CDefObject = $(Get-Content $filePathCDef -raw | ConvertFrom-Json)} catch {Write-Host $filePathCDef}
    $CDefweightClass = $CDefObject.weightClass
    $MDefweightClass = $MDefObject.MechTags.items | Where-Object {$ClassWeights.Keys -contains $_}
    if ($MDefweightClass.Count -gt 1) {
        "$($filePathMDef),more than one weight in mdef" >> $CSV
    } elseif ($MDefweightClass.Count -lt 1) {
        "$($filePathMDef),no weight in mdef" >> $CSV
    } else {
        if ($ClassWeights.$MDefweightClass -notlike $CDefweightClass) {
            "$($filePathMDef),mismatch class" >> $CSV
        }
    }
}