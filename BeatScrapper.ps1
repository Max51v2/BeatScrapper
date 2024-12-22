#Author : Maxime VALLET
#Version : 5.0

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

################################################################################################################################################################


Clear-Host


function doSongExist {
    param (
        [string]$DestPath,
        [string]$SongName
    )
    
    #Check if the song already exists (no matter the format)
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



#Check if the map and destination path were completed (empty by default)
if (($BSPath.Length -eq 0) -or ($DestPath -eq $null) -or ($DestPath -eq "")) {
    #Ask the user to fill them
    if (($DestPath -eq $null) -or ($DestPath -eq "")){
        Write-Error "Please define the following path in th script : DestPath"
    }
    if ($BSPath.Length -eq 0) {
        Write-Error "Please define the following path(s) in th script : BSPath"
    }
    
    #Stops the script
    Break
}


#Check if the format is correct
$checkFormat = ffmpeg -formats -hide_banner -loglevel error | Select-String -Pattern "  $Format  "
if($checkFormat -eq $null){
    Write-Error "The format isn't supported by FFmpeg : $Format"

    #Stops the script
    Break
}

#Check if all the paths in the var BSPath exist in the FS
$BSPathIndex=0
while ($BSPathIndex -le ($BSPath.Length-1)){
    if (-not (Test-Path $BSPath[$BSPathIndex])) {
        $WrongPath = $BSPath[$BSPathIndex]
        Write-Error "Path doesn't exist : $WrongPath"
        Write-Host "Please check your inputs in the BSPath variable"
        Write-Host ""

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
    }
    else {
        Write-Error "There was a problem with the ffmpeg installation"

        #Stops the script
        Break
    }
}

#Defining the codec that will be used (if $IncludeCover is set to "true")
$Preset = "false"
Set-Location $targetPath
$AMD = Get-CimInstance win32_VideoController | Where-Object {$_ -match "amd"} | Select-Object Description
$Nvidia = Get-CimInstance win32_VideoController | Where-Object {$_ -match "nvidia"} | Select-Object Description
$Intel = Get-CimInstance win32_VideoController | Where-Object {$_ -match "intel"} | Select-Object Description

#I used the GPU HW codec, especially H264 since it should be supported by near anything (that's why there is an $OverrideCodec in case the GPU doesn't support it therefore using software H264 (CPU))
if($OverrideCodec -eq "true"){
    $Codec = "libx264"
    $Preset = "true"
}
else{
    if( -not ($AMD -eq $null)){
        $Codec = "h264_amf"
        $Preset = "true"
    }
    elseif( -not ($Nvidia -eq $null)){
        $Codec = "h264_nvenc"
    }
    elseif( -not ($Intel -eq $null)){
        $Codec = "h264_qsv"
    }
    else{
        $Codec = "libx264"
        $Preset = "true"
    }
}
    
#moving to ffmpeg executable folder
Set-Location $targetPath

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
    

#For every maps
$BSPathIndex=0
$c=0
while ($BSPathIndex -le ($BSPath.Length-1)){
    Get-ChildItem -LiteralPath $BSPath[$BSPathIndex] -Directory | ForEach-Object{
        $c=$c+1

        #Map path
        $LevelPath = Join-Path -Path $BSPath[$BSPathIndex] -ChildPath $_.Name

        #Path of the info file that contains the cover and song names
        $SongInfoPath = Join-Path -Path $LevelPath -ChildPath "Info.dat"

        #Check if the Info.dat file exist
        if (-not (Test-Path $SongInfoPath)) {
            $FolderName = $_.Name
            Write-Warning "$c/$MusicNumber - Skipped (no Info.dat) : $FolderName"
                
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

        #If the user chooses to include the cover
        if ($IncludeCover -eq "true") {
            #If the song doesn't exist
            if ($SongFileName -eq $null) {
                #Source music name + format
                $SourceSongName = "$SongFileName.$SongExtension"
                    
                #Full path of the song
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                Write-Warning "No music at this path : "$SongPath
            }
            else {
                if(-not (Test-Path $CoverPath)){
                    Write-Warning "No cover for $SongName"
                    Write-Host "Fallback to .egg"
                        
                    #Dest music name + format
                    $SongDestName = "$SongName.egg"

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

                    #If the music already exist, we skip it
                    if ($SongExist -eq "true"){
                        Write-Host "$c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"
                    }
                    else{
                        #Copy the song
                        Copy-Item -Path $SongPath -Destination $SongDestPath -Force

                        Write-Host "$c/$MusicNumber - Exporting : $SongDestName"
                    }
                }
                else {
                    #Dest music name + format
                    $SongDestName = "$SongName.$Format"

                    #Source music name + format
                    $SourceSongName = "$SongFileName.$SongFileExtension"

                    #Full path of the song
                    $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                    #Full path of where the song will be copied
                    $SongDestPath = Join-Path -Path $DestPath -ChildPath $SongDestName

                    #FFmpeg command
                    if( -not ($AMD -eq $null)){
                        $FFmpegCommand = ".\ffmpeg -loglevel quiet -xerror -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -quality 1 -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`""
                    }
                    elseif($Preset -eq "true"){
                        $FFmpegCommand = ".\ffmpeg -loglevel quiet -xerror -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -preset ultrafast -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`""
                    }
                    else {
                        $FFmpegCommand = ".\ffmpeg -loglevel quiet -xerror -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`"` -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`""
                    }
                        
                    try {
                        #Check if the song already exists (no matter the format)
                        $SongExistObj = doSongExist -DestPath $DestPath -SongName $SongName
                        $SongExist = $SongExistObj.SongExist
                        $SongDestNameTest = $SongExistObj.SongDestNameTest

                        #If the music already exist, we skip it
                        if ($SongExist -eq "true"){
                            Write-Host "$c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"
                        }
                        else{
                            Write-Host "$c/$MusicNumber - Exporting : $SongDestName"

                            Invoke-Expression $FFmpegCommand

                            if ($LASTEXITCODE -ne 0) {
                                throw "FFmpeg error : $LASTEXITCODE"
                            }
                        }
                    } catch {
                        #Deletion of the file (empty here)
                        if(Test-Path $SongDestPath){
                            Remove-Item -LiteralPath $SongDestPath
                        }

                        #Dest music name + format
                        $SongDestName = "$SongName.egg"

                        #Source music name + format
                        $SourceSongName = "$SongFileName.$SongFileExtension"

                        #Full path of the song
                        $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                        #Full path of where the song will be copied
                        $SongDestPath = Join-Path -Path $DestPath -ChildPath $SongDestName

                        Write-Warning "Couldn't create $SongDestName : $_"
                        Write-Host "Fallback to .egg"

                        #Check if the song already exists (no matter the format)
                        $SongExistObj = doSongExist -DestPath $DestPath -SongName $SongName
                        $SongExist = $SongExistObj.SongExist
                        $SongDestNameTest = $SongExistObj.SongDestNameTest

                        #If the music already exist, we skip it
                        if ($SongExist -eq "true"){
                            Write-Host "$c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"
                        }
                        else{
                            #Copy the song
                            Copy-Item -Path $SongPath -Destination $SongDestPath -Force

                            Write-Host "$c/$MusicNumber - Exporting : $SongDestName"
                        }
                    }
                }
            }
        }
        else{
            #Copy the song
            if ($SongFileName -eq $null) {
                #Full path of the song
                $SongPath = Join-Path -Path $LevelPath -ChildPath "$SongFileName.egg"

                Write-Output "No music at this path : $SongPath.egg"
            }
            else {
                #Dest music name + format
                $SongDestName = "$SongName.egg"

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

                #If the music already exist, we skip it
                if ($SongExist -eq "true"){
                    Write-Host "$c/$MusicNumber - Skipped (Exist) : $SongDestNameTest"
                }
                else{
                    #Copy the song
                    Copy-Item -Path $SongPath -Destination $SongDestPath -Force

                    Write-Host "$c/$MusicNumber - Exporting : $SongDestName"
                }
            }
        }
    }

    $BSPathIndex = $BSPathIndex+1
}

Write-Host ""
Write-Host "Done"
Write-Host ""
