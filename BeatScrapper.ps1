#Author : Maxime VALLET
#Version : 11.0


#Script parameter
param ($arg1 = "Default")

########################################################################## Variables ##########################################################################

#Beat Saber maps path(s)
#Add every folder that contains songs (CustomSongs, MultiplayerSongs ...)
#Format : $BSPath = @("Path1", ..., "Path N")
$BSPath = @("/home/max/Téléchargements/BSSongs")

#Folder path where the songs will be stored
$DestPath = "/home/max/Téléchargements/Test"

#Include cover : "true" | "false"
#"false" is faster as it just copies the file
$IncludeCover = "true"

#Export format (has to be supported by FFmpeg and be a video)
#Only work when $IncludeCover="true"
$Format="mp4"

#Number of times the FFmepg benchmark runs 
#Higher means more precision in the estimation but it'll take more time
#Recommended : 3 - 5 
$BenchmarkIterations = 4

#Define if the code uses the default codec : "true" | "false"
#"false" make ffmpeg use adapted GPU HW codec (recommended)
#"true"  make ffmpeg use the software codec (if ffmpeg gives errors or if the songs are empty (caused by the error))
#=> if "true" Windows default player WILL NOT be able to read some songs (no idea why ("incompatible codec settings"))
$OverrideCodec = "false"


###### ADVANCED ######

#Default HW codecs used by FFmpeg
#Warning : some codecs use different flags so you could encounter errors if you modify them (that's why there is a $Preset var)
$AMDCodec = "h264_amf"
$NvidiaCodec = "h264_nvenc"
$IntelCodec = "h264_qsv"

#Default SW codec used by FFmpeg if the GPU isn't from the 3 major brands or if $OverrideCoded="true"
$SWCodec = "libx264"

#Loading pattern displayed when exporting a song 
#Uncomment the one you want
#$CharList = @("|", "/", "-", "\", "|", "/", "-", "\")
$CharList = @("⠇", "⠋", "⠙", "⠸", "⠴", "⠦")
#$CharList = @("⠇⠀", "⠋⠀", "⠉⠁", "⠈⠃", "⠀⠇", "⠠⠆", "⠤⠄", "⠦⠀")
#$CharList = @("|   ", ">   ", " >  ", "  > ", "   >", "   |", "   <", "  < "," <  ","<   ")

#Time in ms between every char change (pattern displayed when exporting a song)
$RefreshPeriod = 200

#Progress bar characters
$BarFillerChar = "■"
$BarHeadChar = "►"
$BarEmptyChar = " "

#Override compatibility check on startup of the script
$OverrideCompatCheck = "false"

#Choose if you want the script to do an FFmpeg Benchmark in order to estimate the time left
$doFFmpegBenchmark = "true"

#Number of exports in between to clear-host (mostly to improve performance)
$global:NBofExportBeforeClearingH = 5

################################################################################################################################################################





######################### Functions #########################

#Check if the song already exists (no matter the format)
function doSongExist {
    param (
        $DestPath,
        $SongName
    )
    
    $SongExist = "false"
    $SongDestNameTest = "none"
    #List every songs in the destination folder and check if the name is identical to the song we're exporting
    Get-ChildItem -LiteralPath $DestPath | Select-Object -ExpandProperty Name | ForEach-Object{
        #Retrieve the song's name in the dest folder
        $SongNameTest = $_ -replace '\.[^.]+$'

        $InvalidCharsPattern = '[:*?"<>|]'
        $SongName = $SongName -replace $InvalidCharsPattern, ''

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
        $SongFileName,
        $SongFileExtension,
        $SongName,
        $LevelPath,
        $DestPath,
        $c,
        $MusicNumber,
        $Format,
        $CoverPath,
        $AMD,
        $Preset,
        $FolderName
    )
    
    #Progression
    $Progression = ($c-1)/$MusicNumber

    #Dest music name + format
    $SongDestName = $SongName+"."+$Format

    #Source music name + format
    $SourceSongName = "$SongFileName.$SongFileExtension"

    #Full path of the song
    $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

    #Full path of where the song will be copied
    $InvalidCharsPattern = '[:*?"<>|]'
    $SongDestName = $SongDestName -replace $InvalidCharsPattern, ''
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
            $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
            $Content = $GetProgressionObj.Content
            Write-Host $Content -NoNewline
            Out-Default

            return
        }

        #Check if the song exists in the map folder
        if (-not (Test-Path -LiteralPath $SongPath)) {
            $global:FullMessage += "E: No music at this path : $SongPath"
            $global:FullMessage += "H: $c/$MusicNumber - Skipped (No song in map folder) : $SongDestName"

            #Refresh Content displayed in the shell
            $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
            $Content = $GetProgressionObj.Content
            Write-Host $Content -NoNewline
            Out-Default

            return
        }

        $global:FullMessage += "H: $c/$MusicNumber - Exporting : $SongDestName"

        #Refresh Content displayed in the shell
        $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
        $Content = $GetProgressionObj.Content
        Write-Host $Content -NoNewline
        Out-Default
        
        #Copy the song
        Copy-Item -LiteralPath $SongPath -Destination $SongDestPath -Force

        #Changing the state from "Exporting" to "Exported" in FullMessage
        $global:FullMessage = $global:FullMessage -replace [regex]::Escape("$c/$MusicNumber - Exporting"), "$c/$MusicNumber - Exported"
    }
    #Video export
    else {
        #If the cover doesn't exist
        if(-not (Test-Path -LiteralPath $CoverPath)){
            $global:FullMessage += "W: No cover for $SongName"
            $global:FullMessage += "H: Fallback to .egg"

            #Refresh Content displayed in the shell
            $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
            $Content = $GetProgressionObj.Content
            Write-Host $Content -NoNewline
            Out-Default

            #Relaunching the function with the EGG format
            exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $c -MusicNumber $MusicNumber -Format "egg" -CoverPath $CoverPath -AMD $AMD -Preset $Preset -FolderName $FolderName

            return
        }
        #If the cover exist
        else {
            #FFmpeg command
            if( -not ($AMD -eq $null)){
                $FFmpegCommand = "$ffmpeg -loglevel error -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -quality 1 -c:a copy -shortest -movflags +faststart `"$SongDestPath`" 2>`"$ErrorLog`""
            }
            elseif($Preset -eq "true"){
                $FFmpegCommand = "$ffmpeg -loglevel error -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -preset ultrafast -c:a copy -shortest -movflags +faststart `"$SongDestPath`" 2>`"$ErrorLog`""
            }
            else {
                $FFmpegCommand = "$ffmpeg -loglevel error -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`"` -c:a copy -shortest -movflags +faststart `"$SongDestPath`" 2>`"$ErrorLog`""
            }

            #Check if the song exists in the map folder
            if (-not (Test-Path -LiteralPath $SongPath)) {
                $global:FullMessage += "E: No music at this path : $SongPath"
                $global:FullMessage += "H: $c/$MusicNumber - Skipped (No song in map folder) : $SongDestName"

                #Refresh Content displayed in the shell
                $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
                $Content = $GetProgressionObj.Content
                Write-Host $Content -NoNewline
                Out-Default

                return
            }

            #If the music already exist, we skip it
            if ($SongExist -eq "true"){
                $global:FullMessage += "H: $c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"

                #Refresh Content displayed in the shell
                $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
                $Content = $GetProgressionObj.Content
                Write-Host $Content -NoNewline
                Out-Default

                return
            }

            $global:FullMessage += "H: $c/$MusicNumber - Exporting : $SongDestName"

            #Clear host only when we reach the defined number of exports
            if ($global:IndexClearH -gt $global:NBofExportBeforeClearingH) {
                Clear-Host

                $global:IndexClearH = 1
            }
            else {
                $global:IndexClearH += 1
            }

            #Refresh Content displayed in the shell
            $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
            $Content = $GetProgressionObj.Content
            Write-Host $Content -NoNewline
            Out-Default

            #Block try-catch to catch FFmepg errors
            try {
                #Job that launches the FFmpeg command in the background
                $job = Start-Job -Name "$c" -ScriptBlock {
                    #Parameters used by the command + path of FFmpeg executable
                    Param($FFmpegCommand, $targetPath)

                    #Launching the command and redirecting errors
                    Invoke-Expression $FFmpegCommand
                } -ArgumentList($FFmpegCommand, $targetPath)

                #Launching the job
                $job | Out-Null

                #job state
                $jobstat = Get-Job -Name "$c" | Select-Object State

                $CharIndex = 0

                #Generate new content with spinner's first char on last line
                $global:AddSpinner = "true"
                $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
                $Content = $GetProgressionObj.Content

                #While the job is running, remplace le pipe placed by DiplayProgression in the last message (repeat with next chars)
                while ((Get-Job -Name "$c").State -eq "Running") {
                    #Refresh Content displayed in the shell
                    Write-Host $Content -NoNewline
                    Out-Default

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
                    $Content = $Content -replace [regex]::Escape(".$Format $Previous"), ".$Format $Next"
                    $Content = $Content -replace [regex]::Escape("$Previous $c/"), "$Next $c/"

                    #Index of the next char
                    if($CharIndex -eq ($CharList.Length - 1)){
                        $CharIndex = 0
                    }
                    else {
                        $CharIndex += 1
                    }

                    #Refreshing time
                    Start-Sleep -Milliseconds $RefreshPeriod
                }

                $global:AddSpinner = "false"

                #Remove the job
                Remove-Job -Name "$c" -Force

                #if there is a log file (imply that there is an error)
                if (Test-Path -LiteralPath $ErrorLog) {
                    #Get FFmpeg errors
                    $errors = Get-Content -LiteralPath $ErrorLog
                    Remove-Item $ErrorLog

                    #If there is errors
                    if ($errors -ne $null) {
                        $d=0
                        #Fill FullMessage with the script error then the FFmpeg error
                        foreach ($line in $errors.Split("`n")) {
                            if($d -eq 0){
                                $global:FullMessage += "E: Couldn't create $SongDestName (Refer to logs for details)"
                            }
                            else {
                                $global:FullMessage += "H: => FFmpeg error : $line"
                            }

                            $d += 1
                        }
                        
                        #Trigger catch clause (=> EGG fallback)
                        throw
                    }

                    #Changing the state from "Exporting" to "Exported" in FullMessage
                    $global:FullMessage = $global:FullMessage -replace [regex]::Escape("$c/$MusicNumber - Exporting"), "$c/$MusicNumber - Exported"
                }
            } 
            catch {
                #Deletion of the file if it exists (would be empty in that case)
                if(Test-Path -LiteralPath $SongDestPath){
                    Remove-Item -LiteralPath $SongDestPath
                }

                #Changing the state from "Exporting" to "Failed" in FullMessage
                $global:FullMessage = $global:FullMessage -replace [regex]::Escape("$c/$MusicNumber - Exporting"), "$c/$MusicNumber - Failed (=>Egg)"

                $global:FullMessage += "H: Fallback to .egg"

                #Refresh Content displayed in the shell
                $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression
                $Content = $GetProgressionObj.Content
                Write-Host $Content -NoNewline
                Out-Default

                #Relaunching the function with the EGG format
                exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $c -MusicNumber $MusicNumber -Format "egg" -CoverPath $CoverPath -AMD $AMD -Preset $Preset -FolderName $FolderName
            }
        }
    }
}



#Create a string that can fill the whole shell's window with the status of the script execution
#Those informations are written to host without clearing the terminal to avoid flashing (though it's not donne in the function because of the spinner)
function GetProgression {
    param (
        $FolderName,
        $Progression,
        $ReplacementChar
    )

    #Width of the Shell Window (in characters)
    $CLIWidth = $Host.UI.RawUI.WindowSize.Width - 2
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

    #Reseting content to display
    #Start with return carriage because the first line the to be the last displayed making it flash (it doesn't matter because it goes out of the shell window because the message takes the windows)
    $Content = "`n"
    
    #For every line we can display in the Shell's Window
    $Line = 0
    $LinesToAdd = 2
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
            $Content += "`n"
        }

        #Folder we're currently exporting from
        if($Line -eq 2){
            $Content += " $FillerChar Exporting from folder : $FolderName"
        }
        #Diplay message from $FullMessage : No offset (codec info etc)
        elseif ($Line -lt 2) {
            #Importance of the message and message itself
            $MessageType = $global:FullMessage[$Line].Substring(0, 1)
            $Message = $global:FullMessage[$Line].Substring(2)

            #Adding the message and it's type to the content that'll be displayed
            if($MessageType -eq "H"){
                $Content += " $FillerChar$Message"
            }
            elseif ($MessageType -eq "W") {
                $Content += ("  "+$FillerChar+"WARNING: $Message")
            }
                elseif ($MessageType -eq "E") {
                $Content += ("  "+$FillerChar+"ERROR : $Message")
            }
        }
        #Diplay message from $FullMessage : offset
        else {
            #Importance of the message and message itself
            $MessageType = $global:FullMessage[$Line + $Offset].Substring(0, 1)
            $Message = $global:FullMessage[$Line + $Offset].Substring(2)

            #Adding the message and it's type to the content that'll be displayed
            if($MessageType -eq "H"){
                #If it's the last line, we add $ReplacementChar (for the animation when Retrieving info about songs)
                if(($Line -eq ($CLIHeight - 1)) -and ($global:AddSpinner -eq "true") -and (! ($ReplacementChar -eq $null))){
                    $Content += " "+$ReplacementChar+"$Message "+$ReplacementChar
                }
                #If it's the last line, we add $CharList[0] (for the animation when exporting songs with the cover)
                elseif(($Line -eq ($CLIHeight - 1)) -and ($global:AddSpinner -eq "true")){
                    $Content += " "+$CharList[0]+"$Message "+$CharList[0]
                }
                else {
                    $Content += " $FillerChar$Message"
                }
            }
            elseif ($MessageType -eq "W") {
                $Content += ("  "+$FillerChar+"WARNING : $Message")
            }
            elseif ($MessageType -eq "E") {
                $Content += ("  "+$FillerChar+"ERROR : $Message")
            }
        }

        $Line += 1
    }


    #Bar content
    $BarContent = "  $FillerChar"
    $BarWidth = $BarContent.Length
    $BarWidthInit = $BarWidth

    #Number of # characters used to fil the bar
    $FillNumber = [math]::Round($Progression * ($CLIWidth-1-$BarWidth))

    #Progression percentage
    $Percentage = [math]::Round($Progression * 100)

    #Filling the extra lines before the progression bar
    while($LinesToAdd -gt 0){
        $Content += "`n"

        $LinesToAdd -= 1
    }
    
    #Filling the bar
    While($BarWidth -le $CLIWidth){
        
        if($BarWidth -eq $BarWidthInit){
            $BarContent += "["
        }
        #No arrow head if ■ is next to the ] at the end
        elseif ($BarWidth -eq ($CLIWidth - 7)) {
            #If the percentage filled is smaller than where the export is
            if($BarWidth -le $FillNumber){
                $BarContent += "$BarFillerChar"
            }
            #If the percentage filled is bigger than where the export is
            else{
                $BarContent += "$BarEmptyChar"
            }
        }
        #Arrow head as long as there is at least 1 empty character between the progression and the ] at the end
        elseif ($BarWidth -lt ($CLIWidth - 6)) {
            #If the percentage filled is smaller than where the export is
            if($BarWidth -le $FillNumber){
                $BarContent += "$BarFillerChar"
            }
            #Adding the arrow head the charcter following the one positionned at the exact exporting percentage
            elseif ($BarWidth -eq ($FillNumber+1)) {
                $BarContent += "$BarHeadChar"
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

    $Content += "$BarContent`n"

    $GetProgressionObj = [PSCustomObject]@{
        Content = $Content
    }

    return $GetProgressionObj
}


#Function that gives the status of the script execution
function Report {
    #Refres the counter for every type of messages
    $GetMessageTypeOccurenceObj = GetMessageTypeOccurence -DesiredMessageType "W"
    $NBWarnings = $GetMessageTypeOccurenceObj.Errors
    $GetMessageTypeOccurenceObj = GetMessageTypeOccurence -DesiredMessageType "E"
    $NBErrors = $GetMessageTypeOccurenceObj.Errors
    $GetMessageTypeOccurenceObj = GetMessageTypeOccurence -DesiredMessageType "S"
    $NBSevereErrors = $GetMessageTypeOccurenceObj.Errors

    Clear-Host

    #If there is a severe error, the script stopped before exporting any song therefore the message change
    if($NBSevereErrors -gt 0){
        Write-Host "`nThe script couldn't export Beat Saber songs because of some errors ^~^`n`n" -ForegroundColor Red
    }
    else {
        Write-Host "`nThe script is done exporting Beat Saber songs ^_^`n`n" -ForegroundColor Green
    }
    
    #Display warings
    Write-Host "Number of Warnings : $NBWarnings" -ForegroundColor Yellow
    PrintMessageType -DesiredMessageType "W"
 
    #Display errors
    Write-Host "Number of Errors : $NBErrors" -ForegroundColor DarkYellow
    PrintMessageType -DesiredMessageType "E"

    #Display severe errors
    Write-Host "Number of Severe Errors : $NBSevereErrors" -ForegroundColor Red
    PrintMessageType -DesiredMessageType "S"

    #Display log path
    Write-Host "Logs available here : $BSLog`n" -ForegroundColor Blue

    #Display feedback message
    Write-Host "Any feedback welcome (new features or bugs) :)`n`n" -ForegroundColor Blue

    #Creation of the logs
    $global:FullMessage += "`n`nNumber of Warnings : $NBWarnings`n`nNumber of Errors : $NBErrors`n`nNumber of Severe Errors : $NBSevereErrors`n"
    $global:FullMessage | Out-File $BSLog -Force

    if($OS -eq "Unix"){
        if(($DestPath -ne "")){
            #Change target folder permission
            sudo chmod 777 -R $DestPath
        }
    }
}


#Count the number of occurence of a defined message type in FullMessage (H/W/E/...)
function GetMessageTypeOccurence {
    param (
        $DesiredMessageType
    )

    $Errors = 0

    #For every lines in FullMessages
    $Line=0
    while($Line -lt $global:FullMessage.Length){
        #Message type of the current line
        $MessageType = $global:FullMessage[$Line].Substring(0, 1)

        #If the type of message is the same as desired
        if($MessageType -eq $DesiredMessageType){
            $Errors += 1
        }

        $Line += 1
    }

    $GetMessageTypeOccurenceObj = [PSCustomObject]@{
        Errors = $Errors
    }

    return $GetMessageTypeOccurenceObj
}


#Print all messages of a specified type (H/W/E/...)
function PrintMessageType {
    param (
        $DesiredMessageType
    )
    
    $Line=0
    while($Line -lt $global:FullMessage.Length){
        #Message type of the current line
        $MessageType = $global:FullMessage[$Line].Substring(0, 1)
        $Message = $global:FullMessage[$Line].Substring(2)

        #If the type of message is the same as desired
        if($MessageType -eq $DesiredMessageType){
            #Printing the line accordingly to it's type
            if($DesiredMessageType -eq "H") {
                Write-Host "$Message" -ForegroundColor Gray
            }
            elseif($DesiredMessageType -eq "W"){
                Write-Host "WARNING :$Message" -ForegroundColor Yellow
            }
            elseif($DesiredMessageType -eq "E") {
                Write-Host "ERROR :$Message" -ForegroundColor DarkYellow
            }
            elseif($DesiredMessageType -eq "S") {
                Write-Host "SEVERE :$Message" -ForegroundColor Red
            }
        }

        $Line += 1
    }

    Write-Host "`n"
}


function PowerShellVersionWarning {
    $global:FullMessage += "S: Please run this script in a compatible PowerShell instance (Current : $CurrentPowerShellVersion | Supported : Windows PowerShell and PowerShell 7)"

    #End Report
    Report
    
    #Stops the script
    break
}


function GetSongInfo {
    param (
        $MapFolderName,
        $CurrentFolder,
        $BSPathIndex,
        $MusicNumber,
        $c,
        $logLevel
    )

    $SkipSong = "false"

    #Map path
    $LevelPath = Join-Path -Path $CurrentFolder -ChildPath $MapFolderName
    
    #Path of the info file that contains the cover and song names
    $SongInfoPath = Join-Path -Path $LevelPath -ChildPath "Info.dat"

    #Check if the Info.dat file exist (silenced)
    if ((-not (Test-Path -LiteralPath $SongInfoPath)) -and ($logLevel -ne "all")) {
        $SkipSong = "true"
    }
     #Check if the Info.dat file exist (not silenced)
    elseif ((-not (Test-Path -LiteralPath $SongInfoPath)) -and ($logLevel -eq "all")) {
        $global:FullMessage += "E: $c/$MusicNumber - Skipped (No Info.dat) : $SongInfoPath"
            
        $SkipSong = "true"
    }
    else {
        #Retrieve the song's name in the map folder
        $json = (Get-Content -LiteralPath $SongInfoPath -Raw -Encoding UTF8) | ConvertFrom-Json
        $Song = $json._songFilename
        $SongFileName = $Song -replace '\.[^.]+$'
        $SongFileExtension =  $Song -replace '.*\.'

        #Retrieve the song's real name
        $json = (Get-Content -LiteralPath $SongInfoPath -Raw -Encoding UTF8) | ConvertFrom-Json
        $Song = $json._songName
        $SongOriginalName = ($Song -replace '\.[^.]+$','') -replace '[<>:"/\\|?*]', ''

        #Retrieve the song's Author name
        $json = (Get-Content -LiteralPath $SongInfoPath -Raw -Encoding UTF8) | ConvertFrom-Json
        $Song = $json._songAuthorName
        $SongAuthorName = $Song -replace '\.[^.]+$'

        #Final song's name
        $SongName = "$SongAuthorName - $SongOriginalName"

        #Retrieve the cover's name
        $json = (Get-Content -LiteralPath $SongInfoPath -Raw -Encoding UTF8) | ConvertFrom-Json
        $Image = $json._coverImageFilename
        $ImageName = $Image -replace '\.[^.]+$'
        $ImageExtension =  $Image -replace '.*\.'

        #Cover path
        $CoverPath = Join-Path -Path $LevelPath -ChildPath "$ImageName.$ImageExtension"

        #Check if the song exist exist (used for size and time calculations)
        $SongExistObj = doSongExist -DestPath $DestPath -SongName $SongName
        $SongExist = $SongExistObj.SongExist
        if ($SongExist -eq "true") {
            $SkipSong = "true"
        }

        $DestSongPath = Join-Path -Path $CurrentFolder -ChildPath $MapFolderName
        $DestSongPath = Join-Path -Path $DestSongPath -ChildPath "$SongFileName.$SongFileExtension"
        if(-not (Test-Path -LiteralPath $DestSongPath)){
            $SkipSong = "true"
        }

        if(-not (Test-Path -LiteralPath $CoverPath)){
            $SkipSong = "true"
        }

        $GetSongInfoObj = [PSCustomObject]@{
            SongName = $SongName
            CoverPath = $CoverPath
            SkipSong = $SkipSong
            SongFileName = $SongFileName 
            SongFileExtension = $SongFileExtension
            LevelPath = $LevelPath
            SongOriginalName = $SongOriginalName
        }
    }

    return $GetSongInfoObj
}


function DeleteBenchSong {
    param (
        $DestPath,
        $SongName,
        $Format
    )
    
    $DestSongPath = Join-Path -Path $DestPath -ChildPath "$SongName.$Format"
    $DestSongPathEgg = Join-Path -Path $DestPath -ChildPath "$SongName.egg"

    if (Test-Path -LiteralPath $DestSongPath) {
        Remove-Item $DestSongPath
    }
    elseif (Test-Path -LiteralPath $DestSongPathEgg) {
        Remove-Item $DestSongPathEgg
    }
}
#############################################################




Clear-Host


#Set shell color
$Host.UI.RawUI.ForegroundColor = 'White'
$Host.UI.RawUI.BackgroundColor = 'Black'

#FullMessage is global because it can be modified in a function while being accessed in another
#It's role is to hold the entirety of the messages that have to be displayed to the user (different than content whhich stores the messages that we currently display)
$global:FullMessage = @()
$global:IndexClearH = 1

#Var init
$Content = ""
$CLI = $arg1
$FillerChar = ""
$c=0
while($c -lt $CharList[0].Length){
    $FillerChar += " "

    $c += 1
}
#Default FFmpeg command for linux (path to bin is set if the OS is Windows)
$ffmpeg = "ffmpeg"
$ffprobe = "ffprobe"


#Remove all jobs that exist
Remove-Job -Name "*" -Force

#Create the target path if it doesn't exist
if (-not (Test-Path -LiteralPath $DestPath)) {
    mkdir $DestPath | Out-Null
}


#FFmpeg log file path
Set-Location $DestPath
$location = Get-Location
$ErrorLog = Join-Path -Path $location.Path -ChildPath "ffmpeg_error.log"

#Script execution log file path
Set-Location $DestPath
$location = Get-Location
$BSLog = Join-Path -Path $location.Path -ChildPath "BeatScrapper_trace.log"



if($OverrideCompatCheck -eq "false"){
    #Check the OS the script is running in
    $OS = [System.Environment]::OSVersion.Platform

    #If if it's a unix based OS we check the distribution
    if($OS -eq "Unix"){
        if (-not (Test-Path -LiteralPath "/usr/bin/apt")){
            $global:FullMessage += "S: Unsuported OS (APT required)"
    
            #End Report
            Report

            #Stops the script
            Break
        }
    }
    elseif($OS -eq "Win32NT"){
        #Nothing
    }
    else{
        $global:FullMessage += "S: Unknown OS : $OS"
    
        #End Report
        Report

        #Stops the script
        Break
    }

    #Check the type of Powershell instance the script is running in
    if($CLI -eq "Default"){
        $CLI = $Host.Name
    }

    #Check for windows terminal (not supported because of jitter)
    if ($env:WT_SESSION) {
        $CurrentPowerShellVersion = "Windows Terminal"

        PowerShellVersionWarning
    }

    #Check for PowerShell Version (ISE : GetProgression broken and char not displaying properly | VSCode : jitter)
    if ($CLI -match "ISE") {
        $CurrentPowerShellVersion = "Windows PowerShell ISE"

        PowerShellVersionWarning
    }  
    elseif ($CLI -match "Visual Studio Code") {
        $CurrentPowerShellVersion = "VSCode"

        PowerShellVersionWarning
    } 
    elseif ($CLI -match "VSCode") {
        $CurrentPowerShellVersion = "VSCode"

        PowerShellVersionWarning
    }
}


#Check if the map and destination path were completed (empty by default)
if (($BSPath.Length -eq 0) -or ($DestPath -eq $null) -or ($DestPath -eq "")) {
    #Ask the user to fill them
    if (($DestPath -eq $null) -or ($DestPath -eq "")){
        $global:FullMessage += "S: Please define the following path in the script : DestPath"
    }
    if ($BSPath.Length -eq 0) {
        $global:FullMessage += "S: Please define the following path(s) in the script : BSPath"
    }
    
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
    if (-not (Test-Path -LiteralPath $BSPath[$BSPathIndex])) {
        $WrongPath = $BSPath[$BSPathIndex]
        $global:FullMessage += "S: Path doesn't exist : $WrongPath"

        #End Report
        Report

        #Stops the script
        Break
    }
    $BSPathIndex = $BSPathIndex+1
}

if($OS -eq "Win32NT"){
    #Winget packet path
    $wingetPackagesDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WinGet\Packages"

    #Search if the program is present (folder here)
    $ProgramName = "ffmpeg.exe"
    $targetPath = Get-ChildItem -Path $wingetPackagesDir -Recurse -File -Filter $ProgramName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty DirectoryName

    #If the file exist then ffmpeg is installed
    if ($targetPath) {
        #Set ffmpeg path to bin
        $targetPathFFmpeg = Join-Path -Path $targetPath -ChildPath $ProgramName
        $targetPathFFprobe = Join-Path -Path $targetPath -ChildPath "ffprobe"
        $ffmpeg = $targetPathFFmpeg
        $ffprobe = $targetPathFFprobe
    } 
    else {
        #While the user doesn't give an accepted anser, we repeat the process
        #We only install FFmpeg if the cover is included
        $Answer = "false"
        $c = 0
        $UserInput = "none"
        if($IncludeCover -eq "true"){
            while($Answer -eq "false"){
                Clear-Host

                if($c -ge 1){
                    Write-Host "Wrong input : $UserInput`n"
                }

                #Ask for user input
                $UserInput = Read-Host -Prompt "FFmpeg is required when exporting with a cover`n`nDo you want to install FFmpeg from the official winget repository ? [proceed | cancel]"

                if(($UserInput -eq "proceed") -or ($UserInput -eq "cancel")){
                    #Answer is obtained
                    $Answer = "true"
                }
                else {
                    $c += 1  
                }
            }
        }
        

        if($UserInput -eq "proceed"){
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

                #Set ffmpeg path to bin
                $targetPathFFmpeg = Join-Path -Path $targetPath -ChildPath $ProgramName
                $targetPathFFprobe = Join-Path -Path $targetPath -ChildPath "ffprobe"
                $ffmpeg = $targetPathFFmpeg
                $ffprobe = $targetPathFFprobe
            }
            else {
                $global:FullMessage += "S: There was a problem with the ffmpeg installation"

                #End Report
                Report

                #Stops the script
                Break
            }
        }
        elseif ($UserInput -eq "cancel") {
            $global:FullMessage += "S: User refused to install FFmpeg"

            #End Report
            Report

            #Stops the script
            Break
        }
    }
}


if($IncludeCover -eq "true"){
    #Check if the format is correct
    $checkFormat = & $ffmpeg -formats -hide_banner -loglevel error | Select-String -Pattern " $Format  "
    if($checkFormat -eq $null){
    $global:FullMessage += "S: The format isn't supported by FFmpeg : $Format"

    #End Report
    Report

    #Stops the script
    Break
}
}


#Defining the codec that will be used (if $IncludeCover is set to "true")
$Preset = "false"
if($OS -eq "Unix"){
    $AMD = $null
    $Nvidia = $null
    $Intel = $null
}
else{
    $AMD = Get-CimInstance win32_VideoController | Where-Object {$_ -match "amd"} | Select-Object Description
    $Nvidia = Get-CimInstance win32_VideoController | Where-Object {$_ -match "nvidia"} | Select-Object Description
    $Intel = Get-CimInstance win32_VideoController | Where-Object {$_ -match "intel"} | Select-Object Description
}


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
}
else {
    $global:FullMessage += "H: Using Hardware codec : $Codec"
}
$global:FullMessage += "H:  "

#Placeholder (skipped when errors are being displayed)
$global:FullMessage += "H:  "


#FFmpeg Benchmark
#Value of time it takes to export a secong of a song
$TimePerSec = 0
if(($doFFmpegBenchmark -eq "true") -and ($IncludeCover -eq "true")){
    $BIIndex = 1
    $global:FullMessage += "H:"
    $FolderName = "FFmpegBenchmark"

    
    #I Think I found a bug in PowerShell
    #When in the while loop in Measure-command, some commands on random iterations wouldn't execute (like I'd get : everything N°1 and only the message for N°3 etc)
    #fix : run every test separately and add the time
    $global:FullMessage += "H: Running Benchmark :"
    $BenchmarkDurationTotMS = 0
    while($BIIndex -le $BenchmarkIterations){
        $BenchmarkDuration = Measure-Command {

            #Retrieve song's informations from info.dat file located in the map's folder
            $GetSongInfoObj = GetSongInfo -MapFolderName $FolderName -CurrentFolder $PSScriptRoot -MusicNumber $BenchmarkIterations -c $BIIndex -logLevel "all"
            $SongName = $GetSongInfoObj.SongName
            $CoverPath = $GetSongInfoObj.CoverPath
            $SkipSong = $GetSongInfoObj.SkipSong
            $SongFileName = $GetSongInfoObj.SongFileName 
            $SongFileExtension = $GetSongInfoObj.SongFileExtension
            $LevelPath = $GetSongInfoObj.LevelPath

            #Bench song deletion
            DeleteBenchSong -DestPath $DestPath -SongName $SongName -Format $Format

            #Export
            exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $BIIndex -MusicNumber $BenchmarkIterations -Format $Format -CoverPath $CoverPath -AMD $AMD -Preset $Preset -SongExist $SongExist -FolderName $FolderName
        }
        $BIIndex += 1

        #Time used by the benchmark
        #Current
        $BenchmarkDurationMS = $BenchmarkDuration | Select-Object TotalMilliseconds

        #Current + past value
        $BenchmarkDurationTotMS = $BenchmarkDurationTotMS + $BenchmarkDurationMS.TotalMilliseconds
    }

    
    #Retrieve the song's length
    $BenchmarkDurationTotMS = [Math]::Round($BenchmarkDurationTotMS)
    $DestSongPath = Join-Path -Path $PSScriptRoot -ChildPath $FolderName
    $DestSongPath = Join-Path -Path $DestSongPath -ChildPath "$SongFileName.$SongFileExtension"
    $MusicDurationS = & $ffprobe -i $DestSongPath -show_entries format=duration -v quiet -of csv="p=0"
    $BenchmarkDurationPerSongMS = [Math]::Round($BenchmarkDurationTotMS/$BenchmarkIterations)
    
    #Calculating the time it takes to export a second of content
    $TimePerSec = [math]::Round(($BenchmarkDurationPerSongMS)/[math]::Round($MusicDurationS),3)

    if($BenchmarkIterations -gt 1){
        $global:FullMessage += "H: Exporting duration ($BenchmarkIterations songs): $TimePerSec ms of Exporting/s"
    }
    else {
        $global:FullMessage += "H: Exporting duration ($BenchmarkIterations song): $TimePerSec ms of Exporting/s"
    }

    #Running skipping Benchmark
    $BIIndex = 1
    $BenchmarkDurationTotMS = 0
    $global:FullMessage += "H:"
    $global:FullMessage += "H: Running Skipping Benchmark :"
    while($BIIndex -le $BenchmarkIterations){
        $BenchmarkDuration = Measure-Command {
            
            #Retrieve song's informations from info.dat file located in the map's folder
            $GetSongInfoObj = GetSongInfo -MapFolderName $FolderName -CurrentFolder $PSScriptRoot -MusicNumber $BenchmarkIterations -c $BIIndex -logLevel "all"
            $SongName = $GetSongInfoObj.SongName
            $CoverPath = $GetSongInfoObj.CoverPath
            $SkipSong = $GetSongInfoObj.SkipSong
            $SongFileName = $GetSongInfoObj.SongFileName 
            $SongFileExtension = $GetSongInfoObj.SongFileExtension
            $LevelPath = $GetSongInfoObj.LevelPath

            #Export
            exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $BIIndex -MusicNumber $BenchmarkIterations -Format $Format -CoverPath $CoverPath -AMD $AMD -Preset $Preset -SongExist $SongExist -FolderName $FolderName
        }
        $BIIndex += 1

        #Time used by the benchmark
        #Current
        $BenchmarkDurationMS = $BenchmarkDuration | Select-Object TotalMilliseconds

        #Current + past value
        $BenchmarkDurationTotMS = $BenchmarkDurationTotMS + [Math]::Round($BenchmarkDurationMS.TotalMilliseconds)
    }

    #Retrieve the song's length
    $BenchmarkDurationPerSongMS = [Math]::Round($BenchmarkDurationTotMS/$BenchmarkIterations)

    if($BenchmarkIterations -gt 1){
        $global:FullMessage += "H: Skipping duration ($BenchmarkIterations songs): $BenchmarkDurationPerSongMS ms per skip"
    }
    else {
        $global:FullMessage += "H: Skipping duration ($BenchmarkIterations songs): $BenchmarkDurationPerSongMS ms per skip"
    }

    #Bench song deletion
    DeleteBenchSong -DestPath $DestPath -SongName $SongName -Format $Format

    #Refresh Content displayed in the shell
    $GetProgressionObj = GetProgression -FolderName $FolderName -Progression 1
    $Content = $GetProgressionObj.Content
    Write-Host $Content -NoNewline
    Out-Default
}

#Fetching how much maps there is so we can display the progression
$MusicNumber=0
$BSPathIndex=0
while ($BSPathIndex -le ($BSPath.Length-1)){
    Get-ChildItem -LiteralPath $BSPath[$BSPathIndex] -Directory | ForEach-Object{$MusicNumber=$MusicNumber+1}

    $BSPathIndex = $BSPathIndex+1
}


#Retrieve info about the maps : length and size
$MusicLengthS = @()
$DopplegangerCheckList = @()
$TotSize = 0
$BSMapIndex = 1
$BSPathIndex=0
$Time = 0
$CharIndex = 0
$SkipNumber = 0
$global:AddSpinner = "true"
$global:FullMessage += "H:"
$global:FullMessage += "H: Retrieving songs' lenth and size :"
#For every folder in BSPath
while ($BSPathIndex -le ($BSPath.Length-1)){
    $FolderName = Split-Path $BSPath[$BSPathIndex] -Leaf

    #For every maps in the specified BSPath folder
    Get-ChildItem -LiteralPath $BSPath[$BSPathIndex] -Directory | ForEach-Object{

        #Really bad implementation of the spinner (change char when exec time > pause between every char)
        #ex : pause between every char = 200 ms
        #   => first cycle = 150 ms => no change (150 < 200)
        #   => second cycle = 150 ms => next char (300 > 200)
        #problem : elapsed time will be on par or greater than the pause (will vary as well)
        #       => the slower the pc, the more obvious it'll be
        #resolution : use a background task like I did on ExportSong but it would take too much time so it'll stay like that
        if($BSMapIndex -gt 1){
            $InfoDurationMS = $InfoDuration | Select-Object TotalMilliseconds
            $InfoDurationMS = $InfoDurationMS.TotalMilliseconds

            $Time = [Math]::Round($Time + $InfoDurationMS)

            #If the elapsed time reaches the treshold, we change the char
            if($Time -gt $RefreshPeriod){
                #Replacing previous char with the next one in $CharList
                $Next = $CharList[$CharIndex]

                #Index of the precedent char (going backwards)
                if($CharIndex -eq 0){
                    $CharIndex = $CharList.Length - 1
                }
                else {
                    $CharIndex -= 1
                }

                $Time = 0
            }
        }

        #Refresh Content displayed in the shell
        $Progression = $BSMapIndex / $MusicNumber
        $GetProgressionObj = GetProgression -FolderName $FolderName -Progression $Progression -ReplacementChar $Next
        $Content = $GetProgressionObj.Content
        Write-Host $Content -NoNewline
        Out-Default

        $InfoDuration = Measure-Command{
            #Retrieve song's informations from info.dat file located in the map's folder
            $GetSongInfoObj = GetSongInfo -MapFolderName $_.Name -CurrentFolder $BSPath[$BSPathIndex] -logLevel "quiet"
            $SongName = $GetSongInfoObj.SongName
            $CoverPath = $GetSongInfoObj.CoverPath
            $SkipSong = $GetSongInfoObj.SkipSong
            $SongFileName = $GetSongInfoObj.SongFileName 
            $SongFileExtension = $GetSongInfoObj.SongFileExtension

            $DestSongPath = Join-Path -Path $BSPath[$BSPathIndex] -ChildPath $_.Name
            $DestSongPath = Join-Path -Path $DestSongPath -ChildPath "$SongFileName.$SongFileExtension"

            #Check every previous entry to verify there wasn't an identical song exported before
            $IndexDoppelgangerCheck = 0
            while($IndexDoppelgangerCheck -lt $DopplegangerCheckList.Length){
                #Check if there is a doppelganger in the list
                if($DopplegangerCheckList[$IndexDoppelgangerCheck] -eq $SongName){
                    $SkipSong = "true"
                }

                $IndexDoppelgangerCheck += 1
            }

            #Retrieve song's length
            if($SkipSong -eq "false"){
                $MusicDurationS = & $ffprobe -i $DestSongPath -show_entries format=duration -v quiet -of csv="p=0"
                $MusicLengthS = $MusicLengthS + [Math]::Round($MusicDurationS)
            }
            else{
                #Adding 0 so both Music length size and $c are the same size (in case i want to add an estimation per song)
                $MusicLengthS = $MusicLengthS + 0

                #Count the number of skipped songs so we can add it later to the estimation (this is especially important on slow PCs as there is a lot of code to run)
                $SkipNumber += 1
            }
            

            #Retrieve song's size
            if($SkipSong -eq "false"){
                #Song size
                $File = Get-Item $DestSongPath -ErrorAction SilentlyContinue
                $TotSize = $TotSize + $File.Length
                
                #Cover size
                if($IncludeCover -eq "true"){
                    $File = Get-Item $CoverPath -ErrorAction SilentlyContinue
                    $TotSize = $TotSize + $File.Length
                }
                
            }

            #We store every map song to check if there is two identical maps that aren't exported yet
            $DopplegangerCheckList += $SongName

            $BSMapIndex += 1
        }
    }

    $BSPathIndex = $BSPathIndex+1
}

$global:AddSpinner = "false"


#Calcultating the time required to export every songs
$c = 0
$TotTimeS = 0
while ($c -lt $MusicLengthS.Length){
    if($MusicLengthS[$c] -gt 0){
        $TotTimeS = $TotTimeS + ($MusicLengthS[$c] * $TimePerSec) / 1000
    }

    $c += 1
}

#Adding every skip in the export time
$TotTimeS = [Math]::Round($TotTimeS + ($SkipNumber * [Math]::Round($BenchmarkDurationPerSongMS/1000,3)))


#Convert the time that is needed to export songs to : HHMMSS
$seconds = $TotTimeS
$minutes = 0
$hours = 0
while(($seconds -ge 60) -or ($minutes -ge 60)){
    if($seconds -ge 60){
        $minutes += 1
        $seconds = $seconds - 60
    }
    if($minutes -ge 60){
        $hours += 1
        $minutes = $minutes - 60
    }
}
if($doFFmpegBenchmark -eq "false"){
    $TotTimeStr = "No time estimation as doFFmpegBenchmark is false"
}
elseif($IncludeCover -eq "false"){
    $TotTimeStr = "No time estimation as IncludeCover is false"
}
else {
    $TotTimeStr = "The estimated time is $hours H $minutes M $seconds S (vary on a per machine and NB of songs basis)"
}
$global:FullMessage += "H: $TotTimeStr"


#If everything is already exported
if(($TotSize -eq 0) -and ($doFFmpegBenchmark -eq "true")){
    $global:FullMessage += "H: All of the songs have already been exported"

    #End Report
    Report

    #Stops the script
    break
}


#Changing Size unity
$UserInput = "none"
if([Math]::Round($TotSize/1Gb,3) -le 1){
    $TotSize = [Math]::Round($TotSize/1Mb,3)
    $TotSizeUnit = "MiB"
}
else{
    $TotSize = [Math]::Round($TotSize/1Gb,3)
    $TotSizeUnit = "GiB"
}

$global:FullMessage += "H: The estimated size required is about $TotSize$TotSizeUnit"


#Display the info abouts songs and ask for user's confirmation
Clear-Host
$Answer = "false"
$c = 0
#While the user doesn't give an accepted anser, we repeat the process
while($Answer -eq "false"){
    Clear-Host

    if($c -ge 1){
        Write-Host "Wrong input : $UserInput`n"
    }

    #Ask for user input
    $Prompt = "  "+$FillerChar+"The estimated size required is about $TotSize$TotSizeUnit (can vary because of the codec).`n`n  "+$FillerChar+"$TotTimeStr .`n`n  "+$FillerChar+"Do you want to export Beat Saber songs ? [proceed | cancel]"
    $UserInput = Read-Host -Prompt $Prompt

    if(($UserInput -eq "proceed") -or ($UserInput -eq "cancel")){
        #Answer is obtained
        $Answer = "true"
    }
    else {
            $c += 1  
    }
}

#Stop the script if the user type cancel
if($UserInput -eq "cancel"){
    $global:FullMessage += "S: User cancelled the export"

    #End Report
    Report

    #Stops the script
    break
}


#Exporting songs (took long enough lmao)
$global:FullMessage += "H: "
$global:FullMessage += "H: Exporting songs :"
$BSPathIndex=0
$c=0
Clear-Host
#For every BS Folder
while ($BSPathIndex -le ($BSPath.Length-1)){
    #Name of the folder we're exporting songs from
    $FolderName = Split-Path $BSPath[$BSPathIndex] -Leaf

    #For every maps in the BS Folder
    Get-ChildItem -LiteralPath $BSPath[$BSPathIndex] -Directory | ForEach-Object{
        $c=$c+1

        #Retrieve song's informations from info.dat file located in the map's folder
        $GetSongInfoObj = GetSongInfo -MapFolderName $_.Name -CurrentFolder $BSPath[$BSPathIndex] -MusicNumber $MusicNumber -c $c -logLevel "all"
        $SongName = $GetSongInfoObj.SongName
        $CoverPath = $GetSongInfoObj.CoverPath
        $SkipSong = $GetSongInfoObj.SkipSong
        $SongFileName = $GetSongInfoObj.SongFileName 
        $SongFileExtension = $GetSongInfoObj.SongFileExtension
        $LevelPath = $GetSongInfoObj.LevelPath

        #Export
        exportSong -SongFileName $SongFileName -SongFileExtension $SongFileExtension -SongName $SongName -LevelPath $LevelPath -DestPath $DestPath -c $c -MusicNumber $MusicNumber -Format $Format -CoverPath $CoverPath -AMD $AMD -Preset $Preset -SongExist $SongExist -FolderName $FolderName
    }
    $BSPathIndex = $BSPathIndex+1
}

#End Report
Report