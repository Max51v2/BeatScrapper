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

    #Create the target path if it doesn't exist
    if (-not (Test-Path $DestPath)) {
        mkdir $DestPath | Out-Null
    }
    

    #For every maps
    $c=0
    Get-ChildItem -LiteralPath $BSPath -Directory | ForEach-Object{
        $c=$c+1

        #Map path
        $LevelPath = Join-Path -Path $BSPath -ChildPath $_.Name

        #Path of the info file that contains the cover and song names
        $SongInfoPath = Join-Path -Path $LevelPath -ChildPath "Info.dat"

        #Check if the Info.dat file exist
        if (-not (Test-Path $SongInfoPath)) {
            $FolderName = $_.Name
            Write-Warning "$c/$MusicNumber - Skipped (no Info.dat) : $FolderName"
            
            return
        }

        #Fetching the song's name in the map folder
        $Song = Get-Content $SongInfoPath | Select-String -Pattern '\"_songFilename\": \".*\"'
        $Song = [regex]::Matches($Song, '[a-z|A-Z]+') | Select-Object Value
        $SongFileName = $Song[1].Value
        $SongFileExtension = $Song[2].Value

        #Fetching the song's real name
        $Song = Get-Content $SongInfoPath | Select-String -Pattern '\"_songName\": \".*\"'
        $Song = [regex]::Matches($Song, '[a-z|A-Z]+') | Select-Object Value
        $SongOriginalName = $Song[1].Value

        #Fetching the song's Author name
        $Song = Get-Content $SongInfoPath | Select-String -Pattern '\"_songAuthorName\": \".*\"'
        $Song = [regex]::Matches($Song, '[a-z|A-Z]+') | Select-Object Value
        $SongAuthorName = $Song[1].Value

        #Final song's name
        $SongName = "$SongAuthorName - $SongOriginalName"

        #Fetching the cover's name
        $Image = Get-Content $SongInfoPath | Select-String -Pattern '\"_coverImageFilename\": \".*\"'
        $Image = [regex]::Matches($Image, '[a-z|A-Z]+') | Select-Object Value
        $ImageName = $Image[1].Value
        $ImageExtension = $Image[2].Value

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
                    $SongExist = "false"
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
                    $SongDestName = "$SongName.mp4"

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
                        $SongExist = "false"
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
                        $SongExist = "false"
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
                $SongExist = "false"
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

Write-Host ""
Write-Host "Done"
Write-Host ""