#Author : Maxime VALLET
#Version : 7.4

########################################################################## Variables ##########################################################################

#Beat Saber maps path(s)
#Add every folder that contains songs (CustomSongs, MultiplayerSongs ...)
#Format : $BSPath = @("Path1", ..., "Path N")
$BSPath = @()

#Folder path where the songs will be stored
$DestPath = ""

#Include cover : "true" | "false"
#"false" is faster as it just copies the file
$IncludeCover = "true"

#Export format (has to be supported by FFmpeg and be a video)
#Only work when $IncludeCover="true"
$Format="mp4"

#Define if the code uses the default codec : "true" | "false"
#"false" make ffmpeg use adapted GPU HW codec (recommended)
#"true"  make ffmpeg use the software codec (if ffmpeg gives errors or if the songs are empty (caused by the error))
$OverrideCodec = "false"


###### ADVANCED ######

#Default HW codecs used by FFmpeg
#Warning : some codecs use different flags so you could encounter errors if you modify them (that's why there is a $Preset var)
$AMDCodec = "h264_amf"
$NvidiaCodec = "h264_nvenc"
$IntelCodec = "h264_qsv"

#Default SW codec used by FFmpeg if the GPU isn't from the 3 major brands or if $OverrideCoded="true"
$SWCodec = "libx264"

################################################################################################################################################################





######################### Functions #########################

#Check if the song already exists (no matter the format)
function doSongExist {
    param (
        [string]$DestPath,
        [string]$SongName
    )
    
    $SongExist = "false"
    $SongDestNameTest = "none"
    #List every songs in the destination folder and check if the name is identical to the song we're exporting
    Get-ChildItem -LiteralPath $DestPath | Select-Object -ExpandProperty Name | ForEach-Object{
        #Fetching the song's name in the dest folder
        $SongNameTest = $_ -replace '\.[^.]+$'

        #If the name of the current music is the same than the one we are exporting
        if ($SongNameTest -eq $SongName){
            $SongExist = "true"
            $SongDestNameTest = $_
        }
    }

    $SongExistObj = [PSCustomObject]@{
        SongExist = $SongExist
        SongDestNameTest = $SongDestNameTest
    }

    return $SongExistObj
}


#Export the song to either EGG or a choosen video format
function exportSong {
    param (
        [string]$SongFileName,
        [string]$SongFileExtension,
        [string]$SongName,
        [string]$LevelPath,
        [string]$DestPath,
        [string]$c,
        [string]$MusicNumber,
        [string]$Format,
        [string]$CoverPath,
        [string]$AMD,
        [string]$Preset,
        [string]$SongExist
    )
    
    #Progression
    $global:Progression = $c/$MusicNumber

    #Dest music name + format
    $SongDestName = "$SongName.$Format"

    #Source music name + format
    $SourceSongName = "$SongFileName.$SongFileExtension"

    #Full path of the song
    $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

    #Full path of where the song will be copied
    $SongDestPath = Join-Path -Path $DestPath -ChildPath $SongDestName

    #Check if the song already exists (no matter the format)
    $SongExistObj = doSongExist -DestPath $DestPath -SongName $SongName
    $SongExist = $SongExistObj.SongExist
    $SongDestNameTest = $SongExistObj.SongDestNameTest

    #EGG export
    if($Format -ieq "egg"){
        #If the music already exist, we skip it
        if ($SongExist -eq "true"){
            $global:FullMessage += "H: $c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"

            #Refresh Content displayed in the shell
            GetProgression
            Write-Host $global:Content

            return
        }

        #Check if the song exists in the map folder
        if (-not (Test-Path $SongPath)) {
            $global:FullMessage += "W: No music at this path : $SongPath"
            $global:NBWarnings +=1
            $global:FullMessage += "H: $c/$MusicNumber - Skipped (No song in map folder) : $SongDestName"

            #Refresh Content displayed in the shell
            GetProgression
            Write-Host $global:Content

            return
        }

        $global:FullMessage += "H: $c/$MusicNumber - Exporting : $SongDestName"

        #Refresh Content displayed in the shell
        GetProgression
        Write-Host $global:Content
        
        #Copy the song
        Copy-Item -Path $SongPath -Destination $SongDestPath -Force
    }
    #Video export
    else {
        #If the cover doesn't exist
        if(-not (Test-Path $CoverPath)){
            $global:FullMessage += "W: No cover for $SongName"
            $global:NBWarnings +=1
            $global:FullMessage += "H: Fallback to .egg"

            #Refresh Content displayed in the shell
            GetProgression
            Write-Host $global:Content

            #Relaunching the function with the EGG format
            exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $c -MusicNumber $MusicNumber -Format "egg" -CoverPath $CoverPath -AMD $AMD -Preset $Preset -SongExist $SongExist

            return
        }
        #If the cover exist
        else {
            #FFmpeg command
            if( -not ($AMD -eq $null)){
                $FFmpegCommand = ".\ffmpeg -loglevel error -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -quality 1 -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`" 2>`"$ErrorLog`""
            }
            elseif($Preset -eq "true"){
                $FFmpegCommand = ".\ffmpeg -loglevel error -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -preset ultrafast -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`" 2>`"$ErrorLog`""
            }
            else {
                $FFmpegCommand = ".\ffmpeg -loglevel error -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`"` -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`" 2>`"$ErrorLog`""
            }

            #Check if the song exists in the map folder
            if (-not (Test-Path $SongPath)) {
                $global:FullMessage += "W: No music at this path : $SongPath"
                $global:NBWarnings +=1
                $global:FullMessage += "H: $c/$MusicNumber - Skipped (No song in map folder) : $SongDestName"

                #Refresh Content displayed in the shell
                GetProgression
                Write-Host $global:Content

                return
            }

            #If the music already exist, we skip it
            if ($SongExist -eq "true"){
                $global:FullMessage += "H: $c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"

                #Refresh Content displayed in the shell
                GetProgression
                Write-Host $global:Content

                return
            }

            $global:FullMessage += "H: $c/$MusicNumber - Exporting : $SongDestName"

            #Refresh Content displayed in the shell
            GetProgression

            #Block try-catch to catch FFmepg errors
            try {
                #Remove all jobs that exist
                Remove-Job -Name "*"

                #Job that launches the FFmpeg command in the background
                $job = Start-Job -Name "$c" -ScriptBlock {
                    #Parameters used by the command + path of FFmpeg executable
                    Param($FFmpegCommand, $targetPath)

                    #Go to the FFmpeg executable folder
                    Set-Location $targetPath

                    #Launching the command and redirecting errors
                    Invoke-Expression $FFmpegCommand
                } -ArgumentList($FFmpegCommand, $targetPath)

                #Launching the job
                $job | Out-Null

                #job state
                $jobstat = Get-Job -Name "$c" | Select-Object State

                #Contains the spinner's pattern (can be changed without other modifications (first is "|"" though => Look for this line '$global:Content += "|$Message |"' to change it))
                $CharList = @("/", "-", "\", "|", "/", "-", "\", "|")
                $CharIndex = 0

                Clear-Host

                #While the job is runnin, remplace le pipe placed by DiplayProgression in the last message (repeat with next chars)
                while ($jobstat.State -ne "Completed") {
                    #Refresh Content displayed in the shell
                    Write-Host $global:Content

                    #job state
                    $jobstat = Get-Job -Name "$c" | Select-Object State
                    
                    #Index of previous char
                    if($CharIndex -eq 0){
                        $LastCharIndex = $CharList.Length - 1
                    }
                    else {
                        $LastCharIndex = $CharIndex - 1
                    }

                    #Replacing previous char with the next one in $CharList
                    $Previous = $CharList[$LastCharIndex]
                    $Next = $CharList[$CharIndex]
                    $global:Content = $global:Content -replace [regex]::Escape(".$Format $Previous"), ".$Format $Next"
                    $global:Content = $global:Content -replace [regex]::Escape("$Previous $c/"), "$Next $c/"

                    #Index of the next char
                    if($CharIndex -eq ($CharList.Length - 1)){
                        $CharIndex = 0
                    }
                    else {
                        $CharIndex += 1
                    }

                    #Refreshing time
                    Start-Sleep -Seconds 0.1
                }

                #if there is a log file (imply that there is an error)
                if (Test-Path $ErrorLog) {
                    #Get FFmpeg errors
                    $errors = Get-Content $ErrorLog
                    Remove-Item $ErrorLog

                    #If there is errors
                    if ($errors -ne $null) {
                        $d=0
                        #Fill FullMessage with the script error then the FFmpeg error
                        foreach ($line in $errors.Split("`n")) {
                            if($d -eq 0){
                                $global:FullMessage += "W: Couldn't create $SongDestName"
                            }
                            else {
                                $global:FullMessage += "=> $line"
                            }
                            

                            $d += 1
                        }
                        
                        
                        #Trigger catch clause (=> EGG fallback)
                        throw
                    }
                }
            } 
            catch {
                #Deletion of the file if it exists (would be empty in that case)
                if(Test-Path $SongDestPath){
                    Remove-Item -LiteralPath $SongDestPath
                }

                $global:FullMessage += "W: Couldn't create $SongDestName (FFmpeg Error) : $errors"
                $global:NBWarnings +=1
                $global:FullMessage += "H: Fallback to .egg"

                #Refresh Content displayed in the shell
                GetProgression
                Write-Host $global:Content

                #Relaunching the function with the EGG format
                exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $c -MusicNumber $MusicNumber -Format "egg" -CoverPath $CoverPath -AMD $AMD -Preset $Preset -SongExist $SongExist
            }
        }
    }
}



#Create a string that can fill the whole shell's window with the status of the script execution
#Those informations are written to host without clearing the terminal to avoid flashing (though it's not donne in the function because of the spinner)
function GetProgression {

    #Width of the Shell Window (in characters)
    $CLIWidth = $Host.UI.RawUI.WindowSize.Width - 1
    #Height of the Shell Window (in characters) minus the progression bar because we don't print messages in those lines
    $CLIHeight = $Host.UI.RawUI.WindowSize.Height - 3

    #Calculating message offset if there is more messages than we can display (display from bottom)
    if($FullMessage.Length -ge $CLIHeight){
        $Offset = $FullMessage.Length - $CLIHeight

        #Offset can't be negative (if window is too narrow)
        if($Offset -lt 0){
            $Offset = 0
        }
    }
    else {
        $Offset = 0
    }

    #For every line we can display in the Shell's Window
    $Line = 0
    $LinesToAdd = 2
    $global:Content = ""
    while ($Line -lt $CLIHeight) {
        #If there is more lines available than there is to display
        if($CLIHeight -gt $FullMessage.Length){
            #Fill with blank until there is 
            while(($CLIHeight - $FullMessage.Length) -gt 0){
                $LinesToAdd += 1

                $CLIHeight -= 1
            }
        }

        #Adds a Newline
        if($Line -ge 1){
            $global:Content += "`n"
        }

        #Folder we're currently exporting from
        if($Line -eq 2){
            $global:Content += "Exporting from folder : $global:FolderName"
        }
        #Diplay message from $FullMessage : No offset (codec info etc)
        elseif ($Line -lt 2) {
            #Importance of the message and message itself
            $MessageType = $global:FullMessage[$Line].Substring(0, 1)
            $Message = $global:FullMessage[$Line].Substring(2)

            #Adding the message and it's type to the content that'll be displayed
            if($MessageType -eq "H"){
                $global:Content += "$Message"
            }
            elseif ($MessageType -eq "W") {
                $global:Content += "WARNING : $Message"
            }
                elseif ($MessageType -eq "E") {
                $global:Content += "ERROR : $Message"
            }
        }
        #Diplay message from $FullMessage : offset
        else {
            #Importance of the message and message itself
            $MessageType = $global:FullMessage[$Line + $Offset].Substring(0, 1)
            $Message = $global:FullMessage[$Line + $Offset].Substring(2)

            #Adding the message and it's type to the content that'll be displayed
            if($MessageType -eq "H"){
                #If it's the last line, we add the | (for the animation)
                if($Line -eq ($CLIHeight - 1)){
                    $global:Content += "|$Message |"
                }
                else {
                    $global:Content += "$Message"
                }
            }
            elseif ($MessageType -eq "W") {
                $global:Content += "WARNING : $Message"
            }
            elseif ($MessageType -eq "E") {
                $global:Content += "ERROR : $Message"
            }
        }

        $Line += 1
    }


    #Number of # characters used to fil the bar
    $FillNumber = [math]::Round($global:Progression * ($CLIWidth-7))

    #Progression percentage
    $Percentage = [math]::Round($global:Progression * 100)

    #Filling the extra lines before the progression bar
    while($LinesToAdd -gt 0){
        $global:Content += "`n"

        $LinesToAdd -= 1
    }
    
    #Filling the bar
    $BarWidth = 0
    $BarContent = ""
    While($BarWidth -le $CLIWidth){
        
        if($BarWidth -eq 0){
            $BarContent += "["
        }
        #No arrow head if ■ is next to the ] at the end
        elseif ($BarWidth -eq ($CLIWidth - 7)) {
            #If the percentage filled is smaller than where the export is
            if($BarWidth -le $FillNumber){
                $BarContent += "■"
            }
            #If the percentage filled is bigger than where the export is
            else{
                $BarContent += " "
            }
        }
        #Arrow head as long as there is at least 1 empty character between the progression and the ] at the end
        elseif ($BarWidth -lt ($CLIWidth - 6)) {
            #If the percentage filled is smaller than where the export is
            if($BarWidth -le $FillNumber){
                $BarContent += "■"
            }
            #Adding the arrow head the charcter following the one positionned at the exact exporting percentage
            elseif ($BarWidth -eq ($FillNumber+1)) {
                $BarContent += "►"
            }
            #If the percentage filled is bigger than where the export is
            else{
                $BarContent += " "
            }
        }
        #If the bar is filled, we add the closing bracket and the percentage
        elseif($BarWidth -eq ($CLIWidth - 4)){
            $BarContent += "] $Percentage%"
        }

        $BarWidth += 1
    }

    $global:Content += "$BarContent"
}


#Function that gives the status of the script execution
function Report {
    Clear-Host
    Write-Host ""
    if($global:NBErrors -gt 0){
        Write-Host "The script couldn't export Beat Saber songs because of some errors ^~^" -ForegroundColor Red
    }
    else {
        Write-Host "The script is done exporting Beat Saber songs ^_^" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Number of Warnings : $global:NBWarnings" -ForegroundColor Yellow
    $Warnings = (Write-Output $global:FullMessage | Select-String -Pattern "W:").Line
    Write-Host ($Warnings -join "`n") -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Number of Errors : $global:NBErrors" -ForegroundColor Red
    $Errors = (Write-Output $global:FullMessage | Select-String -Pattern "E:").Line
    Write-Host ($Errors -join "`n") -ForegroundColor Red
    Write-Host ""
    Write-Host "Script log available here : $BSLog" -ForegroundColor Blue
    Write-Host ""
    Write-Host ""

    #Create the log
    $global:FullMessage += "`n`nNumber of Warnings : $global:NBWarnings`n`nNumber of Errors : $global:NBErrors`n"
    $global:FullMessage | Out-File $BSLog -Force
}
#############################################################




Clear-Host



#Var init : they are global because it'll be modified in a function while being accessed in another
$global:FullMessage = @()
$global:NBErrors = 0
$global:NBWarnings = 0
$global:Content = ""

#FFmpeg log file path
Set-Location $DestPath
$pwd = pwd
$ErrorLog = $pwd.Path+"\ffmpeg_error.log"

#Script execution log file path
Set-Location $DestPath
$pwd = pwd
$BSLog = $pwd.Path+"\BeatScrapper_trace.log"


#Check if the map and destination path were completed (empty by default)
if (($BSPath.Length -eq 0) -or ($DestPath -eq $null) -or ($DestPath -eq "")) {
    #Ask the user to fill them
    if (($DestPath -eq $null) -or ($DestPath -eq "")){
        $global:FullMessage += "E: Please define the following path in th script : DestPath"
        $global:NBErrors +=1
    }
    if ($BSPath.Length -eq 0) {
        $global:FullMessage += "E: Please define the following path(s) in th script : BSPath"
        $global:NBErrors +=1
    }
    
    #End Report
    Report

    #Stops the script
    Break
}


#Check if the format is correct
$checkFormat = ffmpeg -formats -hide_banner -loglevel error | Select-String -Pattern "  $Format  "
if($checkFormat -eq $null){
    $global:FullMessage += "E: The format isn't supported by FFmpeg : $Format"
    $global:NBErrors +=1

    #End Report
    Report

    #Stops the script
    Break
}

#Change the format to EGG if Include cover is false
if($IncludeCover -eq "false"){
    $Format = "egg"
}

#Check if all the paths in the var BSPath exist in the FS
$BSPathIndex=0
while ($BSPathIndex -le ($BSPath.Length-1)){
    if (-not (Test-Path $BSPath[$BSPathIndex])) {
        $WrongPath = $BSPath[$BSPathIndex]
        $global:FullMessage += "E: Path doesn't exist : $WrongPath" 
        $global:NBErrors +=1

        #End Report
        Report

        #Stops the script
        Break
    }
    $BSPathIndex = $BSPathIndex+1
}

#Winget packet path
$wingetPackagesDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WinGet\Packages"

#Search if the program is present (folder here)
$ProgramName = "ffmpeg.exe"
$targetPath = Get-ChildItem -Path $wingetPackagesDir -Recurse -File -Filter $ProgramName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty DirectoryName

#If the file exist then ffmpeg is installed
if ($targetPath) {
    #Nothing
} else {
    Write-Output "Installing ffmpeg"

    #Install ffmpeg
    winget install ffmpeg

    #Winget packet path
    $wingetPackagesDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WinGet\Packages"

    #Search if the program is present (folder here)
    $targetPath = Get-ChildItem -Path $wingetPackagesDir -Recurse -File -Filter $ProgramName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty DirectoryName

    #Check if ffmpeg was installed
    if ($targetPath) {
        #ffmpeg installed
        Clear-Host
    }
    else {
        $global:FullMessage += "E: There was a problem with the ffmpeg installation"
        $global:NBErrors +=1

        #End Report
        Report

        #Stops the script
        Break
    }
}


#Defining the codec that will be used (if $IncludeCover is set to "true")
$Preset = "false"
$AMD = Get-CimInstance win32_VideoController | Where-Object {$_ -match "amd"} | Select-Object Description
$Nvidia = Get-CimInstance win32_VideoController | Where-Object {$_ -match "nvidia"} | Select-Object Description
$Intel = Get-CimInstance win32_VideoController | Where-Object {$_ -match "intel"} | Select-Object Description

#I used the GPU HW codec, especially H264 since it should be supported by near anything (that's why there is an $OverrideCodec in case the GPU doesn't support it therefore using software H264 (CPU))
if($OverrideCodec -eq "true"){
    $Codec = $SWCodec
    $Preset = "true"
}
else{
    if( -not ($AMD -eq $null)){
        $Codec = $AMDCodec
        $Preset = "true"
    }
    elseif( -not ($Nvidia -eq $null)){
        $Codec = $NvidiaCodec
    }
    elseif( -not ($Intel -eq $null)){
        $Codec = $IntelCodec
    }
    else{
        $Codec = $SWCodec
        $Preset = "true"
    }
}

#Codec info
if($Codec -eq "libx264"){
    $global:FullMessage += "W: Using Software codec : $Codec (please Report to @Max51v2 if unintentional)"
    $global:NBWarnings +=1
}
else {
    $global:FullMessage += "H: Using Hardware codec : $Codec"
}
$global:FullMessage += "H:  "

#Fetching how much maps there is so we can display the progression
$MusicNumber=0
$BSPathIndex=0
while ($BSPathIndex -le ($BSPath.Length-1)){
    Get-ChildItem -LiteralPath $BSPath[$BSPathIndex] -Directory | ForEach-Object{$MusicNumber=$MusicNumber+1}

    $BSPathIndex = $BSPathIndex+1
}

#Create the target path if it doesn't exist
if (-not (Test-Path $DestPath)) {
    mkdir $DestPath | Out-Null
}
    
#moving to ffmpeg executable folder
Set-Location $targetPath

#For every BS Folder
$BSPathIndex=0
$c=0
while ($BSPathIndex -le ($BSPath.Length-1)){
    #Name of the folder we're exporting songs from
    $global:FolderName = Split-Path $BSPath[$BSPathIndex] -Leaf

    #Placeholder (skipped when errors are being displayed)
    $global:FullMessage += "H:  "

    #For every maps in the BS Folder
    Get-ChildItem -LiteralPath $BSPath[$BSPathIndex] -Directory | ForEach-Object{
        $c=$c+1

        #Map path
        $LevelPath = Join-Path -Path $BSPath[$BSPathIndex] -ChildPath $_.Name

        #Path of the info file that contains the cover and song names
        $SongInfoPath = Join-Path -Path $LevelPath -ChildPath "Info.dat"

        #Check if the Info.dat file exist
        if (-not (Test-Path $SongInfoPath)) {
            $global:FolderName = $_.Name
            $global:FullMessage += "W: $c/$MusicNumber - Skipped (No Info.dat) : $global:FolderName"
            $global:NBWarnings +=1
                
            return
        }

        #Fetching the song's name in the map folder
        $json = (Get-Content $SongInfoPath -Raw) | ConvertFrom-Json
        $Song = $json._songFilename
        $SongFileName = $Song -replace '\.[^.]+$'
        $SongFileExtension =  $Song -replace '.*\.'

        #Fetching the song's real name
        $json = (Get-Content $SongInfoPath -Raw) | ConvertFrom-Json
        $Song = $json._songName
        $SongOriginalName = ($Song -replace '\.[^.]+$','') -replace '[<>:"/\\|?*]', ''

        #Fetching the song's Author name
        $json = (Get-Content $SongInfoPath -Raw) | ConvertFrom-Json
        $Song = $json._songAuthorName
        $SongAuthorName = $Song -replace '\.[^.]+$'

        #Final song's name
        $SongName = "$SongAuthorName - $SongOriginalName"

        #Fetching the cover's name
        $json = (Get-Content $SongInfoPath -Raw) | ConvertFrom-Json
        $Image = $json._coverImageFilename
        $ImageName = $Image -replace '\.[^.]+$'
        $ImageExtension =  $Image -replace '.*\.'

        #Cover path
        $CoverPath = Join-Path -Path $LevelPath -ChildPath "$ImageName.$ImageExtension"

        #Export
        exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $c -MusicNumber $MusicNumber -Format $Format -CoverPath $CoverPath -AMD $AMD -Preset $Preset -SongExist $SongExist    
    }

    $BSPathIndex = $BSPathIndex+1
}

#End Report
Report