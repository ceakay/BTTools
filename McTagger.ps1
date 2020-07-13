#Resize powershell window
$Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size("150","2000")
$Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size("150","60")
#Do tool setup
$ToolSetupCheck = $false
do {
    #Prompt for path to dev root directory
    $ModtekCheck = $false
    do {
        Clear-Host
        Write-Host "Path to dev root must contain unique instance of ModTek\ModTek.dll`r`n"
        $PathToDevRoot = Read-Host -Prompt "Enter path to dev root"
        # If the user didn't give us an absolute path, 
        # resolve it from the current directory.
        if( -not [IO.Path]::IsPathRooted($PathToDevRoot) )
        {
            $PathToDevRoot = Join-Path -Path (Get-Location).Path -ChildPath $PathToDevRoot
        }
        $PathToDevRoot = Join-Path -Path $PathToDevRoot -ChildPath '.'
        $PathToDevRoot = [IO.Path]::GetFullPath($PathToDevRoot)
        #search for unique instance of Modtek.dll
        if ($(Get-ChildItem -Path $PathToDevRoot -Recurse -Include "ModTek.dll").Count -eq 1) {
            #Set true path to dev root
            $PathToDevRoot = split-path -path $(split-path -path $(Get-ChildItem -Path $PathToDevRoot -Recurse -Include "modtek.dll").FullName -Parent) -Parent
            $ModtekCheck = $true
        }
    } until ($ModtekCheck)

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
    #Prompt for Mechs/Vehicles/Gear
        #Mechs Prompt for Mech/PA
        #Vehicles prompt for Tanks/VTOL
        #Gear prompt for Weapons/Equipment
    #Do Settings Confirm
    Clear-Host
    Write-Host @"
Dev Root Path: $PathToDevRoot
Skip files with existing flag: $FlagSkip
"@
    $SettingsConfirm = Read-Host -Prompt "Confirm settings (y/n)"
    if ($SettingsConfirm -like "y*") {
        $ToolSetupCheck = $true
    }
} until ($ToolSetupCheck)

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
`t Type: Specify either Chassis or Mech (Specifying Mech includes VehicleDef - basically the NOT ChassisDef file)
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
`t`t 2) Multi-Line to Collection use a //UNIQUE// '_-MLC-_value' tag
`t`t Once you've selected a tag, dump your multiline json structure into a plaintext .txt file with of the same name.
`t`t`t (Example tag/filename) Tag: '_-MLA-_BFG4Everyone'; Filename: '_-MLA-_BFG4Everyone.txt'

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

