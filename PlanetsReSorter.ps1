###FUNCTIONS
#data chopper function
    #args: delimiter, position, input
function datachop {
    $array = @($args[2] -split "$($args[0])")
    return $array[$args[1]]
}

###SET CONSTANTS
###
$FileName = "CareerDifficultySettings.json"
$HolderFile = "$PSScriptRoot\\holder.txt"
$OutFile = "$PSScriptRoot\\$FileName"

#Prompt for path to dev root directory
$FileCheck = $false
Clear-Host
Write-Output @"
PlanetsReSorter
Will create resorted $FileName in $PSScriptRoot

Git: github.com/ceakay/BTTools

"@
do {
    Write-Output "Path to dev root must contain unique instance of $FileName`r`n"
    $SearchPath = Read-Host -Prompt "Enter path to search for $FileName"
    # If the user didn't give us an absolute path,
    # resolve it from the current directory.
    if( -not [IO.Path]::IsPathRooted($SearchPath) )
    {
        $SearchPath = Join-Path -Path (Get-Location).Path -ChildPath $SearchPath
    }
    $SearchPath = Join-Path -Path $SearchPath -ChildPath '.'
    $SearchPath = [IO.Path]::GetFullPath($SearchPath)
    #search for unique instance of file
    $SearchItem = $(Get-ChildItem -Path $SearchPath -Recurse -Filter $FileName)
    if ($SearchItem.Count -eq 1) {
        #Set true path to dev root
        $SearchPath = $SearchItem.FullName
        Write-Output @"


Found File: $SearchPath
"@
        $PathConfirm = Read-Host -Prompt "Use file? (y)"
        if ($PathConfirm -like 'y*') {
            $FileCheck = $true
        }
    } elseif ($SearchItem.Count -gt 1) {
        Clear-Host
        Write-Output "Found more than 1 instance of $FileName`r`n"
    } else {
        Clear-Host
        Write-Output "Found no instances of $FileName`r`n"
    }
} until ($FileCheck)

$CareerStartsFile = $SearchPath
$CareerStartsMaster = Get-Content $CareerStartsFile -Raw | ConvertFrom-Json
$PlanetsMaster = $CareerStartsMaster.difficultyList | Where-Object {$_.ID -eq 'diff_startingplanet'}

#Clone into PlanetsOld
$PlanetsOld = $PlanetsMaster.Options | Select-Object *

#create name lists
$PlanetsNameListOld = $PlanetsMaster.Options.Name
$PlanetsNameListOld > $HolderFile
Invoke-Expression $HolderFile
Write-Output "Temp file opened. Reorder, save file, and close. When ready, press Enter to continue."
pause
$PlanetsNameListNew = Get-Content $HolderFile | Where-Object {$_}

#Generate new object
$PlanetsNew = @()
foreach ($PlanetName in $PlanetsNameListNew) {
    $PlanetsNew += $PlanetsOld | Where-Object {$_.Name -eq $PlanetName}
}

#overwrite planetsmaster.options
$PlanetsMaster.Options = $PlanetsNew
#object is already linked because i didn't clone out, write object to file.
$CareerStartsMaster | ConvertTo-Json -Depth 99 | Out-File $OutFile -Encoding utf8

#Cleanup
Remove-Item $HolderFile