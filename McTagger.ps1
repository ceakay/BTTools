#Resize powershell window
$Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size("2000","2000")
$Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size("150","80")

#Average + Round function
Function AvgRound($array)
{
    $RunningTotal = 0
    foreach($i in $array){
        $RunningTotal += $i
    }
    return [math]::Round(([decimal]($RunningTotal) / [decimal]($array.Length)))
}

#Declare class weights hash
$ClassWeights = @{
    unit_light = "LIGHT"
    unit_medium = "MEDIUM"
    unit_heavy = "HEAVY"
    unit_assault = "ASSAULT"
    unit_superheavy = "SUPERHEAVY"
}

#Hardpoint Types
$HardTypes = @('Ballistic','Energy','Missile','AntiPersonnel','Omni')

#Sorted array weights

#Tool Pre-setup
#Prompt for path to dev root directory
$ModtekCheck = $false
do {
    Clear-Host
    Write-Host @"
Welcome to McTagger.
This script is designed for adding custom mod flags individually to units.
Use another script if your intention is to work batches of units, or even all of them. 
Git: github.com/ceakay/BTTools
"@
    Write-Host ""
    Write-Host "Path to dev root must contain unique instance of ModTek.dll`r`n"
    $PathToDevRoot = Read-Host -Prompt "Enter path to search for dev root"
    # If the user didn't give us an absolute path, 
    # resolve it from the current directory.
    if( -not [IO.Path]::IsPathRooted($PathToDevRoot) )
    {
        $PathToDevRoot = Join-Path -Path (Get-Location).Path -ChildPath $PathToDevRoot
    }
    $PathToDevRoot = Join-Path -Path $PathToDevRoot -ChildPath '.'
    $PathToDevRoot = [IO.Path]::GetFullPath($PathToDevRoot)
    #search for unique instance of Modtek.dll
    if ($(Get-ChildItem -Path $PathToDevRoot -Recurse -Filter "ModTek.dll").Count -eq 1) {
        #Set true path to dev root
        $PathToDevRoot = split-path -path $(split-path -path $(Get-ChildItem -Path $PathToDevRoot -Recurse -Filter "ModTek.dll").FullName -Parent) -Parent
        Write-Host @"


Found Dev Root Path: $PathToDevRoot
"@
        $PathConfirm = Read-Host -Prompt "Work with path as dev root (y?)"
        if ($PathConfirm -like 'y*') {
            $ModtekCheck = $true
        }
    }
} until ($ModtekCheck)

<# never mind this was a terrible idea. snagged some json errors tho
#Init Master Object
$MasterObjectList = @()
$JSONList = Get-ChildItem $PathToDevRoot -Recurse -Filter "*.json"
$i = 0
"" > error.txt
foreach ($JSONFile in $JSONList) {
    Write-Progress -Activity "Initializing JSONs" -Status "$($i+1) of $($JSONList.Count) JSONs found."
    Try {
        $JSONRaw = Get-Content $JSONFile.FullName -Raw
        #Remove dirty comments >=(
        $JSONRaw = $($($JSONRaw -replace '(?<=\/\*)((?ms).*?)(?=\*\/)',$null) -split "`n" | where {$_ -notmatch "//"} | where {$_ -notmatch "/\*\*/"}) -join "`n"
        $MasterObjectList += $($JSONRaw | ConvertFrom-Json -depth 99)
    } Catch {
        "===" >> error.txt
        $JSONFile.FullName >> error.txt
        "---" >> error.txt
        $Error[0] >> error.txt
    }
    $i++
}
#>

#Do tool setup
$ToolSetupCheck = $false
do {
    <#Don't need this anymore
    #Prompt to skip where flags exist
    $FlagSkipCheck = $false
    do {
        Clear-Host
        $FlagSkip = Read-Host -Prompt "Skip files with existing flag set (y/n)"
        if ($FlagSkip -like "y*") {
            $FlagSkip = $true
            $FlagSkipCheck = $true
        } elseif ($FlagSkip -like "n*") {
            $FlagSkip = $false
            $FlagSkipCheck = $true
        }
    } until ($FlagSkipCheck)
    #>
    #Prompt for Mechs/Vehicles/Gear
    $TypeSelectCheck = $false
    do {
        Clear-Host
        Write-Host @"
Types:
1) PA/ProtoMech
2) Mechs
3) Tanks
4) VTOL
"@
        <#
        Type Notes
        PA/Proto need seperate parse due to combined classes unit_powerarmor, unit_protomech
        VTOL need seperate parse due to unique weight classes
        Gear is a fucking pain to parse. Not implementing in forseeable future

        #>
        $TypeSelect = Read-Host -Prompt "Select Type (1-4)"
        
        if (($TypeSelect % 1 -eq 0) -and ($TypeSelect -ge 1 -or $TypeSelect -le 4)) {
            $TypeSelectText = switch ($TypeSelect) {
                1 {'PA/Protomech'}
                2 {'Mechs'}
                3 {'Tanks'}
                4 {'VTOL'}
            }
            $WeightSelectCheck = $false
            if ($TypeSelect -ne 1) {
                do {
                    Clear-Host
                    Write-Host "Weights:"
                    $WeightsTextArray = @('LIGHT','MEDIUM','HEAVY','ASSAULT','SUPERHEAVY')
                    for ($i=0; $i -lt $WeightsTextArray.Count; $i++) {
                        Write-Host "$($i+1)) $($WeightsTextArray[$i])"
                    }
                    $WeightSelect = Read-Host -Prompt "Select weight class to work with (1-5 or ALL)"
                    switch ($WeightSelect) {
                        { @(1..5) -contains $_} { $WeightSelectText = $WeightsTextArray[$_-1]; $WeightSelectCheck = $true}
                        'all' { $WeightSelectText = 'ALL'; $WeightSelectCheck = $true}
                        default {}
                    }
                } until ($WeightSelectCheck)
            }
            $TypeSelectCheck = $true
        }
    } until ($TypeSelectCheck)
    #Do Settings Confirm
    Clear-Host
    Write-Host @"
Skip files with existing flag: $FlagSkip
Selected Type: $TypeSelectText
"@
    if ([bool]$WeightSelectText) {
        Write-Host "`tSelected Weight: $WeightSelectText"
    }
    Write-Host "`r`n`r`n"
    $SettingsConfirm = Read-Host -Prompt "Confirm settings (y/n)"
    if ($SettingsConfirm -like "y*") {
        $ToolSetupCheck = $true
    }
} until ($ToolSetupCheck)
al
#Do Config Confirm
$ConfigConfimCheck = $false
do {
    Clear-Host
    if ($ConfigHelp) {
        Write-Host @"
=== How to form TagConfig.csv ===
TagConfig.csv allows for setting more than one Tag at the same time. CSV to allow for human readable/editable (i.e. Excel).
Must exist in same directory as tool.
Tool does not parse multiline entries directly from CSV. MLEs are assumed to  See Below

Line 1: Type/Path/To/TagName
`t Use '/' as delimiter. Will trim any leading or tailing delimiters/
`t If there is only 1 Key, script will bypass asking for key to work with.
`t Type: Specify either Chassis or Type (Type will tell script to save to MechDef or VehicleDef - basically the NOT ChassisDef file)
`t Path/To: Object path to tag. CAUTION: Will create every single object key along the way if required. Check your spelling!
`t TagName: The name of the tag you want to add. 

Line 2+: Values
`t List possible values from line 2 onwards. 
`t To prompt for a value, use '_-Value-_' in line 2.
`t`t (Example) Line1: 'Mech/Description/Cost' Line2: '_-Value-_'
`t`t`t Will prompt for a value, and add '"Cost": YourValue' to Mech/Description
`t To add the TagName to an array/list, use '_-Array-_' in line 2. Path/To should include the array's name. 
`t`t (Example) Line1: 'mech/MechTags/items/unit_legendary'; Line2: '_-Array-_'
`t`t`t Will add 'unit_legendary' to MechTags/Items in MechDef
`t To add a multi-line entries, there are two options:
`t`t It is recommended you validate the JSON structure before hand, script will hard stop on invalid structures. i.e. https://jsonlint.com
`t`t 1) Multi-Line to Array use a //UNIQUE// '_-MLA-_value' tag
`t`t`t MLA will append the entire structure as-is to the end of array
`t`t 2) Multi-Line to Collection use a //UNIQUE// '_-MLC-_value' tag
`t`t`t MLC will append the key/value pairs, over-writing any existing keys with the new value. 
`t`t Once you've selected a tag, dump your multiline json structure into a json file with of the same name.
`t`t`t (Example tag/filename) Tag: '_-MLA-_BFG4Everyone'; Filename: '_-MLA-_BFG4Everyone.json'

==================================
"@
        Read-Host -Prompt "Enter to continue"
        Clear-Host
        $ConfigHelp = $false
    }
    Write-Host "=== Review TagConfig.csv ==="
    #Parse TagConfig.csv
    $TagFile = Join-Path -Path $PSScriptRoot -ChildPath "TagConfig.csv"
    $CSVRawObject = Import-Csv -path $TagFile
    $KeysList = @($CSVRawObject | Get-Member -MemberType Properties).Name
    $KeysObject = [pscustomobject]@{}
    foreach ($Key in $KeysList) {
        $Key = $Key.Trim('/')
        Add-Member -InputObject $KeysObject -MemberType NoteProperty -Name $Key -Value @()
        $KeysObject.$Key = $($CSVRawObject | select -ExpandProperty $Key)
        $KeysObject.$Key = $($KeysObject.$Key | Where-Object {$_})
    }
    $KeysObject | ft
    $ConfigConfirm = Read-Host -Prompt "Confirm config file (y/n/help)"
    if ($ConfigConfirm -like "y*") {
        $ConfigConfimCheck = $true
    } elseif ($ConfigConfirm -like "n*") {
        Read-Host -Prompt "Press Enter after you've fixed and saved config"
    } elseif ($ConfigConfirm -like "help") {
        $ConfigHelp = $true
    }
} until ($ConfigConfimCheck)

#count number of Keys. if only 1, set ($ValuesOnly -eq $true)

#Filter and Gather objects
Clear-Host
Write-Host 'Preparing Tool'
Write-Host 'Gathering JSON Objects'

switch ($TypeSelect) {
    1 {
        $TypeFile1Filter = 'mechdef*.json'
        $TypeFile2Filter = 'chassisdef*.json'
        $TypeConditionFile = '$TDef'
        $TypeConditionName = "MechTags.items"
        $TypeConditionComp = ""
        $TypeConditionValue = "unit_powerarmor|unit_protomech"
    }
    2 {
        $TypeFile1Filter = 'mechdef*.json'
        $TypeFile2Filter = 'chassisdef*.json'
        $TypeConditionFile = '$TDef'
        $TypeConditionName = "MechTags.items"
        $TypeConditionComp = "-notmatch"
        $TypeConditionValue = "unit_powerarmor|unit_protomech"
    }
    3 {
        $TypeFile1Filter = 'vehicledef*.json'
        $TypeFile2Filter = 'vehiclechassisdef*.json'
        $TypeConditionFile = '$TDef'
        $TypeConditionName = "VehicleTags.items"
        $TypeConditionComp = "-notmatch"
        $TypeConditionValue = "unit_vtol"
    }
    4 {
        $TypeFile1Filter = 'vehicledef*.json'
        $TypeFile2Filter = 'vehiclechassisdef*.json'
        $TypeConditionFile = '$TDef'
        $TypeConditionName = "VehicleTags.items"
        $TypeConditionComp = ""
        $TypeConditionValue = "unit_vtol"
    }
    #TypeConditions search CDef
}
if ($WeightSelectCheck -and ($WeightSelectText -notlike 'all')) {
    $WeightsFilter = ' | Select-String -pattern "'+$($ClassWeights.GetEnumerator() | ? {$_.Value -like $WeightSelectText}).Name+'"'
} else {
    $WeightsFilter = ''
}
#Build List of all mechs
#Filtering done with Select-String - Construct the entire command before running iex
$TypeFileList = Invoke-Expression $('Get-ChildItem $PathToDevRoot -Recurse -Filter $TypeFile1Filter'+$WeightsFilter+' | '+$("Select-String "+$TypeConditionComp+" -pattern `""+$TypeConditionValue+"`" -List")+' | Select-Object Path | Get-ChildItem')

#Formatting
$Sep = ""
do {
    $Sep = $Sep + "="
} until ($Sep.Length -eq 149)

#Mech/Vehicle Processing
if (($TypeSelect -ge 1) -and ($TypeSelect -le 4)) {
    #construct mega component object list
    #get a list of jsons
    $ComponentObjectList = @()
    $ComponentFilter = "*`"ComponentType`"*"
    $JSONList = Get-ChildItem $PathToDevRoot -Recurse -Filter "*.json"
    $i = 0
    foreach ($JSONFile in $JSONList) {
        Write-Progress -Activity "Collecting Components" -Status "Scanning $($i+1) of $($JSONList.Count) JSONs found."
        $JSONRaw = Get-Content $JSONFile.FullName -Raw
        if ($JSONFile.FullName -notmatch 'MechEngineer') {
            if ($JSONRaw -like $ComponentFilter) {
                try {
                    $ComponentObjectList += $($JSONRaw | ConvertFrom-Json)
                } catch { Write-Host "Malformed JSON: $JSONFile" }
            }
        }
        $i++
    }
    #Build hashes from objectlist
    $ComponentIDNameHash = @{} 
    $ComponentObjectList | % {$ComponentIDNameHash.Add($_.Description.ID,$_.Description.UIName)}
    $ComponentIDStealthHash = @{}    
    $ComponentObjectList | % { if ([bool]($_.Custom.BonusDescriptions.Bonuses -match 'stealth')) {$ComponentIDStealthHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentIDJumpsHash = @{}    
    $ComponentObjectList | % { if ([bool]($_.Custom.BonusDescriptions.Bonuses -match 'JumpCapacity')) {$ComponentIDJumpsHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentIDActEquipHash = @{}    
    $ComponentObjectList | % { if ([bool]($_.Custom.BonusDescriptions.Bonuses -match 'Activatable')) {$ComponentIDActEquipHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentIDIndirHash = @{}    
    $ComponentObjectList | % { if ([bool]($_.IndirectFireCapable -eq $true)) {$ComponentIDIndirHash.Add($_.Description.ID,$true)} }
    $ComponentIDMeleeHash = @{}    
    $ComponentObjectList | % { if ([bool]($_ -match 'SpecialMelee')) {$ComponentIDMeleeHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentObjectList | % { if ([bool]($_.Custom.Category -match 'SpecialMelee')) {$ComponentIDMeleeHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentIDMinRangeHash = @{}
    $ComponentObjectList | ? {$_.Custom.Category.CategoryID} | % { if ([bool]($_.Custom.Category.CategoryID.Split('/')[0] -eq 'w')) {$ComponentIDMinRangeHash.Add($_.Description.ID,$_.MinRange)} }
    $ComponentIDMidRangeHash = @{}
    $ComponentObjectList | ? {$_.Custom.Category.CategoryID} | % { if ([bool]($_.Custom.Category.CategoryID.Split('/')[0] -eq 'w')) {$ComponentIDMidRangeHash.Add($_.Description.ID,$_.RangeSplit)} }
    $ComponentIDMaxRangeHash = @{}
    $ComponentObjectList | ? {$_.Custom.Category.CategoryID} | % { if ([bool]($_.Custom.Category.CategoryID.Split('/')[0] -eq 'w')) {$ComponentIDMaxRangeHash.Add($_.Description.ID,$_.MaxRange)} }
    $ComponentIDRatingHash = @{}
    $ComponentObjectList | % { if ([bool]($_.Custom.EngineCore.Rating)) {$ComponentIDRatingHash.Add($_.Description.ID,$_.Custom.EngineCore.Rating)} }
    $ComponentIDQuirkHash = @{}
    $ComponentObjectList | ? {$_.Custom.Category.CategoryID} | % { if ([bool]($_.Custom.Category.CategoryID -match 'quirk')) {$ComponentIDQuirkHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentIDWeaponHash = @{}
    $ComponentObjectList | ? {$_.Custom.Category.CategoryID} | % { if ([bool]($_.Custom.Category.CategoryID.Split('/')[0] -eq 'w')) {$ComponentIDWeaponHash.Add($_.Description.ID,$_.Description.UIName)} }
    $ComponentIDDriveHash = @{
        'PA_Legs' = 'PowerArmor'
        'emod_armorslots_LAM' = 'LAM'
        'Gear_Hover_Left' = 'Hover'
        'Gear_Armored_Hover_Left' = 'Arm. Hover'
        'Gear_VTOL' = 'VTOL'
        'Gear_VTOL_Reinforced' = 'Arm. VTOL'
        'Gear_Tracked_Left' = 'Tracked'
        'Gear_Armored_Tracked_Left' = 'Arm. Tracked'
        'Gear_Wheeled_Left' = 'Wheeled'
        'Gear_Armored_Wheeled_Left' = 'Arm. Wheeled'
    }
    $ComponentMountHash = @{
        'Head' = 'HD'
        'CenterTorso' = 'CT'
        'LeftTorso' = 'LT'
        'RightTorso' = 'RT'
        'LeftArm' = 'LA'
        'RightArm' = 'RA'
        'LeftLeg' = 'LL'
        'RightLeg' = 'RL'
        'Front' = 'VF'
        'Rear' = 'VB'
        'Left' = 'VL'
        'Right' = 'VR'
        'Turret' = 'VT'
    }
    #Collect WeightClass Averages
    $ClassAverages = [pscustomobject]@{}
    foreach ($Class in $ClassWeights.Keys) {
        $ClassAverages | Add-Member -NotePropertyName $Class -NotePropertyValue $([pscustomobject]@{})
        Start-Job -Name $Class -ScriptBlock {
            $ClassAvgJobObj = [pscustomobject]@{}
            $ClassAvgJobObj | Add-Member -NotePropertyName AllNames -NotePropertyValue @()
            $ClassAvgJobObj | Add-Member -NotePropertyName AllTonnage -NotePropertyValue @()
            $ClassAvgJobObj | Add-Member -NotePropertyName AllMaxArmor -NotePropertyValue @()
            $ClassAvgJobObj | Add-Member -NotePropertyName AllSetArmor -NotePropertyValue @()
            $ClassAvgJobObj | Add-Member -NotePropertyName AllEngine -NotePropertyValue @()
            $i=0
            foreach ($ClassTypeFile in $using:TypeFileList) {
                $ClassOnlyTypeRaw = Get-Content $ClassTypeFile.FullName -Raw
                if ($ClassOnlyTypeRaw -match $using:Class) {
                    $ClassOnlyType = $ClassOnlyTypeRaw | ConvertFrom-Json
                    try {
                        $ClassOnlyChassis = Get-Content -Raw $(Get-ChildItem (Split-Path $ClassTypeFile.DirectoryName -Parent) -Recurse -Filter "$($ClassOnlyType.ChassisID)*").FullName | ConvertFrom-Json
                    } catch {
                        $ClassOnlyChassis = Get-Content -Raw @(Get-ChildItem $using:PathToDevRoot -Recurse -Filter "$($ClassOnlyType.ChassisID)*")[0].FullName | ConvertFrom-Json
                    }
                    $ClassAvgJobObj.AllNames += $ClassOnlyType.Description.UIName
                    $ClassAvgJobObj.AllTonnage += $ClassOnlyChassis.Tonnage
                    $MaxTotal = 0
                    $($ClassOnlyChassis.Locations | select -Property MaxArmor).MaxArmor | % {$MaxTotal += $_}
                    $($ClassOnlyChassis.Locations | select -Property MaxRearArmor | ? {$_.MaxRearArmor -ge 0}).MaxRearArmor | % {$MaxTotal += $_}
                    $ClassAvgJobObj.AllMaxArmor += $MaxTotal
                    $SetTotal = 0
                    $($ClassOnlyType.Locations | select -Property AssignedArmor).AssignedArmor | % {$SetTotal += $_}
                    $($ClassOnlyType.Locations | select -Property AssignedRearArmor | ? {$_.AssignedRearArmor -ge 0}).AssignedRearArmor | % {$SetTotal += $_}
                    $ClassAvgJobObj.AllSetArmor += $SetTotal
                    $Engine = $($ClassOnlyType.inventory -match 'emod_engine_[0-9]{3}').ComponentDefID
                    if (!$Engine) { $Engine = $($ClassOnlyChassis.FixedEquipment -match 'emod_engine_[0-9]{3}').ComponentDefID }
                    $Engine = @($Engine -split '\s+')[0]
                    $Engine = [int]([regex]::Matches($Engine,'[0-9]{3}').Value)
                    $ClassAvgJobObj.AllEngine += $Engine
                }
                $i++
            }
            return $ClassAvgJobObj
        }
    }
    while((Get-Job | Where-Object {$_.State -ne "Completed"}).Count -gt 0) {
        Start-Sleep -Milliseconds 250
        Write-Progress -id 0 -Activity 'Gathering Class Averages'
        foreach ($job in (Get-Job)) {
            Write-Progress -Id $job.Id -Activity $job.Name -Status $job.State -ParentId 0
        }
    }
    foreach ($Class in $ClassWeights.Keys) {
        $ClassAverages.$Class = Get-Job | ? {$_.Name -eq $Class} | Receive-Job | Select-Object * -ExcludeProperty RunspaceId, PSSourceJobInstanceId
        #Do Averages Math
        if ($($ClassAverages.$Class.AllNames).Count -ne 0) {
            $ClassAverages.$Class | Add-Member -NotePropertyName AvgTonnage -NotePropertyValue (AvgRound(@($ClassAverages.$Class.AllTonnage)))
            $ClassAverages.$Class | Add-Member -NotePropertyName AvgMaxArmor -NotePropertyValue (AvgRound(@($ClassAverages.$Class.AllMaxArmor)))
            $ClassAverages.$Class | Add-Member -NotePropertyName AvgSetArmor -NotePropertyValue (AvgRound(@($ClassAverages.$Class.AllSetArmor)))
            $ClassAverages.$Class | Add-Member -NotePropertyName AvgEngine -NotePropertyValue (AvgRound(@($ClassAverages.$Class.AllEngine)))
        }
    }
    Get-Job | Remove-Job
    #Cleanup Averages Job
    
    
    for ($m=0; $m -lt $TypeFileList.Count; $m++) {
        $TDefFile = $TypeFileList[$m]
        $TDefRaw = Get-Content $TDefFile.FullName -raw
        $TDef = $TDefRaw | ConvertFrom-Json
        $CDefFile = Get-ChildItem (Split-Path $TDefFile.DirectoryName -Parent) -Recurse -Filter "$($TDef.ChassisID)*"
        $CDefRaw = Get-Content $CDefFile.FullName -raw
        $CDef = $CDefRaw | ConvertFrom-Json
        $MechAllEquip = $TDef.inventory + $CDef.FixedEquipment
        $CheckMech = $false
        #Reset Tag/Value display
        $DisplayValue = $false
        if ($ValuesOnly -eq $true) {
            $DisplayValue = $true
        }
        Do {
            $LineNum = 0
            Write-Host $Sep
            #Header
            Write-Host @"
   TypeDef: $($TDefFile.FullName)
ChassisDef: $($CDefFile.FullName)
$Sep
"@
            $LineNum = $LineNum+3
            #Mech Stats
            $MechStats1 = "   MechStats || Name: $($TDef.Description.Name)"
            if ($MechStats1.Length -gt 73) {
                $MechStats1 = $MechStats1.Substring(0,73)
            }
            do {$MechStats1 += " "} until ($MechStats1.Length -ge 74)
            $MechStats1 += "|| Tonnage: $($CDef.Tonnage)"
            do {$MechStats1 += " "} until ($MechStats1.Length -ge 94)
            $MechEngine = $($TDef.inventory -match 'emod_engine_[0-9]{3}').ComponentDefID
            if (!$MechEngine) { $Engine = $($CDef.FixedEquipment -match 'emod_engine_[0-9]{3}').ComponentDefID }
            $MechEngine = @($MechEngine -split '\s+')[0]
            $MechEngine = [int]([regex]::Matches($MechEngine,'[0-9]{3}').Value)
            try {[int]$MechSpeed = $MechEngine / $CDef.Tonnage} catch {Write-Error "$MechEngine | $($CDefFile.FullName)"}
            $MechStats1 += "|| Speed: $MechSpeed"
            do {$MechStats1 += " "} until ($MechStats1.Length -ge 114)
            $MechStats1 += "|| Armor: $($($TDef.Locations | Measure-Object -Property AssignedArmor -Sum).Sum) / $($($CDef.Locations | Measure-Object -Property MaxArmor -Sum).Sum)"
            Write-Host $MechStats1; $LineNum++
            #Mech Parts
            #More parts todo: arty [indirect], melee, ammo?, [activatable], turret?, drivesys (vtol, lam, hover, etc.)
            $MechStealth = $false
            $MechJumps = $false
            $MechMelee = $false
            $MechIndir = $false
            $HardBallistic = 0
            $HardMissile = 0
            $HardEnergy = 0
            $HardAntiPersonnel = 0
            $HardOmni = 0
            $HardText = ''
            $MechQuirks = ''
            $MechActEquip = ''
            #1 - hardpoints|stealth|jumps|DriveSys
            $CDef.Locations.Hardpoints | ? {$_.WeaponMount} | % { if (-not $_.Omni) {iex ('$Hard' + $_.WeaponMount + ' += 1')} else {$HardOmni += 1} }
            foreach ($HardType in $HardTypes) {
                if ($HardType[0] -like 'A') {
                    $HardShort = 'S'
                } else {
                    $HardShort = $HardType[0]
                }
                $HardTypeCount = iex ('$Hard'+$HardType)
                if ($HardTypeCount -gt 0) {
                    $HardText += " "+$HardShort+":"+$HardTypeCount
                }
            }
            $MechParts1 = "   MechParts || Hardpoints |"+$HardText
            do {$MechParts1 += " "} until ($MechParts1.Length -ge 74)
            if (@(Compare-Object @($ComponentIDStealthHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).Count -gt 0) {$MechStealth = $true}
            $MechParts1 += "|| Stealth: $MechStealth"
            do {$MechParts1 += " "} until ($MechParts1.Length -ge 94)
            if (@(Compare-Object @($ComponentIDJumpsHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).Count -gt 0) {$MechJumps = $true}
            $MechParts1 += "|| Jumps: $MechJumps"
            do {$MechParts1 += " "} until ($MechParts1.Length -ge 114)
            #DriveSys
            $DriveCompare = @(Compare-Object @($ComponentIDDriveHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).InputObject
            if ($DriveCompare.Count -gt 0) {$MechDrive = $ComponentIDDriveHash.$DriveCompare} else {$MechDrive = 'Bipedal'}
            $MechParts1 += "|| DriveSys: $MechDrive"
            if ($MechParts1.Length -gt 150) {
                $MechParts1 = $MechParts1.Substring(0,150)
            }
            Write-Host $MechParts1; $LineNum++
            #2 - Quirk|Melee|Indir|ActEquip
            @(Compare-Object @($ComponentIDQuirkHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).InputObject | % {$MechQuirks += '| ' + $ComponentIDQuirkHash.$_ + ' '}
            $MechParts2 = "             || Quirks $MechQuirks"
            if ($MechParts2.Length -gt 73) {
                $MechParts2 = $MechParts2.Substring(0,73)
            }
            do {$MechParts2 += " "} until ($MechParts2.Length -ge 74)
            if (@(Compare-Object @($ComponentIDMeleeHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).Count -gt 0) {$MechMelee = $true}
            $MechParts2 += "|| Melee: $MechMelee"
            do {$MechParts2 += " "} until ($MechParts2.Length -ge 94)
            if (@(Compare-Object @($ComponentIDIndirHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).Count -gt 0) {$MechIndir = $true}
            $MechParts2 += "|| Indir: $MechIndir"
            do {$MechParts2 += " "} until ($MechParts2.Length -ge 114)
            if (@(Compare-Object @($ComponentIDActEquipHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).Count -gt 0) {
                @($(Compare-Object @($ComponentIDActEquipHash.Keys) $MechAllEquip.ComponentDefID -IncludeEqual -ExcludeDifferent).InputObject) | % {$MechActEquip += '| '+ $ComponentIDActEquipHash.$_ +' '}
            }
            if ($MechActEquip -eq '') {
                $MechActEquip = "| None"
            }
            $MechParts2 += "|| Actives $MechActEquip"
            if ($MechParts2.Length -gt 150) {
                $MechParts2 = $MechParts2.Substring(0,150)
            }
            Write-Host $MechParts2; $LineNum++
            #Class Stats
            [string]$MechClass = $ClassWeights.$($TDef.MechTags.items | ? {$ClassWeights.Keys -contains $_})
            $ClassStats1 = "  ClassStats || Class: $MechClass"
            do {$ClassStats1 += " "} until ($ClassStats1.Length -ge 74)
            $ClassStats1 += "|| AvgTon: $($ClassAverages.$($TDef.MechTags.items | ? {$ClassWeights.Keys -contains $_}).AvgTonnage)"
            do {$ClassStats1 += " "} until ($ClassStats1.Length -ge 94)
            [int]$AvgSpeed = $($ClassAverages.$($TDef.MechTags.items | ? {$ClassWeights.Keys -contains $_}).AvgEngine) / $($ClassAverages.$($TDef.MechTags.items | ? {$ClassWeights.Keys -contains $_}).AvgTonnage)
            $ClassStats1 += "|| AvgSpd: $AvgSpeed"
            do {$ClassStats1 += " "} until ($ClassStats1.Length -ge 114)
            $ClassStats1 += "|| AvgArm: $($ClassAverages.$($TDef.MechTags.items | ? {$ClassWeights.Keys -contains $_}).AvgSetArmor) / $($ClassAverages.$($TDef.MechTags.items | ? {$ClassWeights.Keys -contains $_}).AvgMaxArmor)"
            Write-Host $ClassStats1; $LineNum++
            Write-Host $Sep; $LineNum++
            
            #Equipment List
            Write-Host 'Equipment List'; $LineNum++
            Write-Host $Sep; $LineNum++
            $EquipListColSizeRaw = $MechAllEquip.ComponentDefID.count / 4
            [int]$EquipListColSize = 0.499+$EquipListColSizeRaw
            $MountList = @{}
            $MountList.Add('ColA',@($MechAllEquip.MountedLocation[0..$($EquipListColSize-1)]))
            $MountList.Add('ColB',@($MechAllEquip.MountedLocation[$($EquipListColSize)..$($EquipListColSize *2 -1)]))
            $MountList.Add('ColC',@($MechAllEquip.MountedLocation[$($EquipListColSize *2)..$($EquipListColSize *3 -1)]))
            $MountList.Add('ColD',@($MechAllEquip.MountedLocation[$($EquipListColSize *3)..$($MechAllEquip.ComponentDefID.count -1)]))
            $EquipmentList = @{}
            $EquipmentList.Add('ColA',@($MechAllEquip.ComponentDefID[0..$($EquipListColSize-1)]))
            $EquipmentList.Add('ColB',@($MechAllEquip.ComponentDefID[$($EquipListColSize)..$($EquipListColSize *2 -1)]))
            $EquipmentList.Add('ColC',@($MechAllEquip.ComponentDefID[$($EquipListColSize *2)..$($EquipListColSize *3 -1)]))
            $EquipmentList.Add('ColD',@($MechAllEquip.ComponentDefID[$($EquipListColSize *3)..$($MechAllEquip.ComponentDefID.count -1)]))
            $ColNames = @('ColA','ColB','ColC','ColD')
            for ($n=0; $n -lt $EquipListColSize; $n++) {
                $EquipRowText = "|"
                $EquipColWidth = 37
                $ColNames | % {
                    $EquipRowText += try {iex ('$ComponentMountHash.$($MountList.'+$_+'['+$n+'])')} catch {}
                    $EquipRowText += "| "
                    $EquipListItem = iex ('$($EquipmentList.'+$_+'['+$n+'])')
                    $EquipRowText += try {$ComponentIDNameHash.$EquipListItem} catch {}
                    if ([bool]$(try{$ComponentIDWeaponHash.$EquipListItem} catch {$false})) {
                        $EquipRowText += try {' ['+$ComponentIDMinRangeHash.$EquipListItem+','+$ComponentIDMidRangeHash.$EquipListItem[0]+','+$ComponentIDMaxRangeHash.$EquipListItem+']'} catch {}
                    }
                    if ($EquipRowText.Length -gt $($EquipColWidth-1)) {
                        $EquipRowText = $EquipRowText.Substring(0,$($EquipColWidth-1))
                    }
                    do {$EquipRowText += " "} until ($EquipRowText.Length -ge $EquipColWidth)
                    $EquipRowText += "|"
                    $EquipColWidth += 37
                }
                $EquipRowTextArray = $EquipRowText.Split('[')
                for ($i=0; $i -lt $EquipRowTextArray.Count; $i++) {
                    if ($i -gt 0) {
                        $EquipRowTextArraySub = $($EquipRowTextArray[$i].Split("|"))
                        Write-Host $("[" + $EquipRowTextArraySub[0]) -NoNewline -ForegroundColor Yellow 
                        $EquipRowTextArraySub[1..$($EquipRowTextArraySub.Count -1)] | % {Write-Host $("|" + $_) -NoNewline}
                    } else {
                        Write-Host $($EquipRowTextArray[$i]) -NoNewline
                    }
                }
                Write-Host $('')
            }
            $LineNum += $EquipListColSize
            Write-Host $Sep; $LineNum++

            #Tag/Value Table
            ##THIS NEEDS TO BE REWORKED. HASHTABLES AREN'T ORDERED.
            if ($DisplayValue) {
                [ref]$ValueTableRow = 0; Import-Csv -path $TagFile | ft @{ N="Value"; E={"{0}" -f ++$ValueTableRow.value}; A="right"},*
                $LineNum += $ValueTableRow.Value+4
            } else {
                $TagTable = @{}; [ref]$TagTableRow = 1; $(Get-Content $TagFile)[0].Split(',') | % {$TagTable.Add($TagTableRow.Value,$_); $TagTableRow.Value++}; $TagTable.GetEnumerator() | Sort-Object -property Name | Format-Table @{L='Tag';E={$_.Name}},@{L='';E={$_.Value}}
                $LineNum += $TagTableRow.Value+4
            }
            #Fill remaining lines including 76
            do {
                $LineNum++
                Write-Host ""
            } until ($LineNum -eq 76)
            #Describe Possible Actions Line 77
            switch ($Select) {
                'write' {
                    Write-Host "Confirm Save To $($SaveTo[0])Def (Commit)"; $LineNum++
                    $Save1 = $true
                }
                'commit' {Write-Host "$($SaveTo[0])Def Saved"}
                'commiterrorimjustbeinglazywhywouldyoutypethisin' {Write-Host "Need to (Write) before (Commit)"}
                default {
                    if (!$SelectError) {
                        Write-Host ""; $LineNum++
                    } else {
                        Write-Host "Error: $SelectError"; $LineNum++
                    }
                }
            }
            $SelectError = $null
            $Select = $null
            $SelectNumMod = $null
            #Line 78
            Write-Host "Use numbers to select Tag/Value | (Tag#.Value#) to specify both. !Will commit and finish! [i.e. 2.5]"
            #Line 79
            Write-Host "(Write) to save file | (WC) to repeat last tag and [$LastTag] | (Finish) at anytime to move to next def"
            #Get action - Line 80
            [String]$Select = Read-Host -Prompt "Action"
            switch ($Select) {
                'write' {}
                'commit' {
                    if ($Save1) {
                        #do write here
                    } else {
                        $Select = 'commiterrorimjustbeinglazywhywouldyoutypethisin'
                    }
                }
                'commiterrorimjustbeinglazywhywouldyoutypethisin' {}
                'wc' {
                    #repeat last tag here
                }
                'finish' {$CheckMech = $true}
                default {
                    try {
                        $SelectNum = $Select / 1
                        if ($SelectNum -is [int]) {
                            if ($DisplayValue) {
                                #Do values work
                                if ($ValuesOnly -eq $false) {
                                    $DisplayValue = (-not $DisplayValue)
                                }
                            } else {
                                #Do tags work
                                $DisplayValue = (-not $DisplayValue)
                            }
                        } else {
                            $EZTag = @($Select -split "\.")
                            if (($EZTag.Count -ne 2) -or ($EZTag[0] -le 0)) {
                                #Throw error
                            } else  {
                                #do eztag work
                                #Reset displayvalue
                                $DisplayValue = $false
                            }
                        }
                    } catch {$SelectError = 'Invalid Input'}    
                }
            }
            $Save1 = $false
        } until ($CheckMech)
    }
    Clear-Host
    Write-Host 'Done'
}
#Elseif gear processing
