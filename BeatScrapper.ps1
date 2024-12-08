#Author : Maxime VALLET
#Version : 3.0

########################################################################## Variables ##########################################################################

#Beat Saber maps path
$BSPath = ""

#Folder path where the songs will be stored
$DestPath = ""

#Include cover : "true" | "false"
#"false" is faster as it just copies the file
$IncludeCover = "true"

#Define if the code uses the default codec : "true" | "false"
#"false" make ffmpeg use adapted GPU HW codec (recommended)
#"true"  make ffmpeg use the software codec (if ffmpeg gives errors or if the songs are empty (caused by the error))
$OverrideCodec = "false"

################################################################################################################################################################


Clear-Host

#Check if the map and destination path were completed ("" by default)
if (($BSPath -eq $null) -or ($DestPath -eq $null) -or ($BSPath -eq "") -or ($DestPath -eq "")) {
    #Ask the user to fill them
    if (($DestPath -eq $null) -or ($DestPath -eq "")){
        Write-Warning "Please define the following path in th script : DestPath"
    }
    if (($BSPath -eq $null) -or ($BSPath -eq "")) {
        Write-Warning "Please define the following path in th script : BSPath"
    }
    
    #Stops the script
    Break
}
else{
    #Check if BSPath exist in the FS
    if (-not (Test-Path $BSPath)) {
        Write-Warning "Path doesn't exist : $BSPath"

        #Stops the script
        Break
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
            Write-Warning "There was a problem with the ffmpeg installation"

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
    Get-ChildItem -LiteralPath $BSPath -Directory | ForEach-Object{$MusicNumber=$MusicNumber+1}

    #For every maps
    $c=0
    Get-ChildItem -LiteralPath $BSPath -Directory | ForEach-Object{
        #Map path
        $LevelPath = Join-Path -Path $BSPath -ChildPath $_.Name

        #reseting variables
        $SongName = $null
        $SongExtension = $null
        $FolderName = $_.Name
        $ImageName = $null
        $ImageExtension = $null

        #For every file in the map folder
        Get-ChildItem -LiteralPath $LevelPath | ForEach-Object {
            #Fetching the song
            if ($_.Extension -match "^\.(egg|wav|mp3)$") {
                $SongName = $_.BaseName
                $SongExtension = $_.Extension
            }

            #Fetching the cover (the one named cover or the first image as there is instances where there is multiple images)
            if ($_.Extension -match "^\.(jpg|png|jpeg|jfif|tiff|bmp)$") {
                if(($ImageName -eq $null) -or ($_.Name -eq "cover")){
                    $ImageName = $_.Name
                    $ImageExtension = $_.Extension
                }
            }
        }

        $c=$c+1

        #If the user chooses to include the cover
        if ($IncludeCover -eq "true") {
            #If the song doesn't exist
            if ($SongName -eq $null) {
                #Source music name + format
                $SourceSongName = $SongName+$SongExtension
                
                #Full path of the song
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                Write-Warning "No music at this path : "$SongPath
            }
            else {
                if($ImageName -eq $null){
                    #Dest music name + format
                    $DestSongName = $FolderName+".egg"

                    #Source music name + format
                    $SourceSongName = $SongName+$SongExtension

                    #Full path of the song
                    $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                    #Full path of where the song will be copied
                    $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                    #Copy the song
                    Copy-Item -Path $SongPath -Destination $SongDestPath -Force
                }
                else {
                    #Dest music name + format
                    $DestSongName = $FolderName+".mp4"

                    #Source music name + format
                    $SourceSongName = $SongName+$SongExtension

                    #Full path of the song
                    $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                    #Full path of where the song will be copied
                    $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                    #Cover path
                    $CoverPath = Join-Path -Path $LevelPath -ChildPath $ImageName

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
                        #Check if the song already exists
                        if (Test-Path $SongDestPath){
                            Write-Host "$c/$MusicNumber - Skipped (Exist) : $DestSongName"
                        }
                        else{
                            Write-Host "$c/$MusicNumber - Exporting : $DestSongName"

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
                        $DestSongName = $FolderName+".egg"

                        #Source music name + format
                        $SourceSongName = $SongName+$SongExtension

                        #Full path of the song
                        $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                        #Full path of where the song will be copied
                        $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                        Write-Warning "Couldn't create $SongName : $_"
                        Write-Host "Fallback to .egg"

                        #Check if the song already exists
                        if (Test-Path $SongDestPath){
                            Write-Host "$c/$MusicNumber - Skipped (Exist) : $DestSongName"
                        }
                        else{
                            #Copy the song
                            Copy-Item -Path $SongPath -Destination $SongDestPath -Force

                            Write-Host "$c/$MusicNumber - Exporting : $DestSongName"
                        }
                    }
                }
            }
        }
        else{
            #Copy the song
            if ($SongName -eq $null) {
                #Full path of the song
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                Write-Output "No music at this path : "$SongPath
            }
            else {
                #Dest music name + format
                $DestSongName = $FolderName+".egg"

                #Source music name + format
                $SourceSongName = $SongName+$SongExtension

                #Full path of the song
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SourceSongName

                #Full path of where the song will be copied
                $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                #Check if the song already exists
                if (Test-Path $SongDestPath){
                    Write-Host "$c/$MusicNumber - Skipped (Exist) : $DestSongName"
                }
                else{
                    #Copy the song
                    Copy-Item -Path $SongPath -Destination $SongDestPath -Force

                    Write-Host "$c/$MusicNumber - Exporting : $DestSongName"
                }
            }
        }
    }
}

Write-Host "Done"
