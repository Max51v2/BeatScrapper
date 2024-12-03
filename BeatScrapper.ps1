########################################################################## À Modifier ##########################################################################
#Chemin d'accès des maps BS
$BSPath = "C:\Users\Maxime\BSManager\BSInstances\1.39.1\Beat Saber_Data\CustomLevels"

#Fichier où les musiques seront transferées
$DestPath = "C:\Users\Maxime\Downloads\test"

#Cover : "true" | "false"
#"false" plus rapide
$IncludeCover = "true"

#Codec par défaut (s'il y'a une erreur de codec avec ffmpeg) : "true" | "false"
#"false" par défaut
$OverrideCodec = "true"

#################################################################################################################################################################


Clear-Host

#Vérification de la présence des chemins dans le script (maps et dest)
if (($BSPath -eq $null) -or ($DestPath -eq $null) -or ($BSPath -eq "") -or ($DestPath -eq "")) {
    if (($BSPath -eq $null) -or ($DestPath -eq "")){
        Write-Warning "Le chemin n'a pas été renseigné : DestPath"
    }
    else {
        Write-Warning "Le chemin n'a pas été renseigné : BSPath"
    }
    
    #Arrêt du script
    Break
}
else{
    #Vérification de l'éxitance du chemin spécifié
    if (-not (Test-Path $BSPath)) {
        Write-Warning "Le chemin est introuvable : $BSPath"

        #Arrêt du script
        Break
    }

    #Nom du programme à chercher
    $ProgramName = "ffmpeg.exe"

    #Répertoire principal des packages Winget
    $wingetPackagesDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WinGet\Packages"

    #Recherche du fichier dans les sous-répertoires
    $targetPath = Get-ChildItem -Path $wingetPackagesDir -Recurse -File -Filter $ProgramName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty DirectoryName

    if ($targetPath) {
        #Rien
    } else {
        Write-Output "Installation de ffmpeg"

        #Installation de FFmpeg s'il ne l'est pas
        winget install ffmpeg

        #Répertoire principal des packages Winget
        $wingetPackagesDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WinGet\Packages"

        #Recherche du fichier dans les sous-répertoires
        $targetPath = Get-ChildItem -Path $wingetPackagesDir -Recurse -File -Filter $ProgramName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty DirectoryName

        if ($targetPath) {
            #ffmpeg isntallé
        }
        else {
            Write-Warning "Problème d'installation de ffmpeg"

            #Arrêt du script
            Break
        }
    }

    #Définition du codec (ceux pour amd et nvidia sont supporté depuis très longtemps (pré adaptateur vidéo lol) donc je ne vérifie pas s'il est dispo sur le GPU)
    $Preset = "false"
    Set-Location $targetPath
    $AMD = Get-CimInstance win32_VideoController | Where-Object {$_ -match "amd"} | Select-Object Description
    $Nvidia = Get-CimInstance win32_VideoController | Where-Object {$_ -match "nvidia"} | Select-Object Description

    #Définition du codec utilisé par ffmpeg
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
        else{
            $Codec = "libx264"
            $Preset = "true"
        }
    }
    

    #Récupération du nombre de maps
    $MusicNumber=0
    Get-ChildItem -LiteralPath $BSPath -Directory | ForEach-Object{$MusicNumber=$MusicNumber+1}

    #Listage des maps
    $c=0
    Get-ChildItem -LiteralPath $BSPath -Directory | ForEach-Object{
        #Chemin de la map
        $LevelPath = Join-Path -Path $BSPath -ChildPath $_.Name

        #Réinitialisation des variables
        $SongName = $null
        $SongExtension = $null
        $ImageName = $null
        $ImageExtension = $null

        #Listage du contenu de la map
        Get-ChildItem -LiteralPath $LevelPath | ForEach-Object {
            #Récupération du nom et de l'extension de la musique (format egg)
            if ($_.Extension -ieq ".egg" || $_.Extension -ieq ".wav") {
                $SongName = $_.Name
                $SongExtension = $_.Extension
            }

            # Récupération du nom et de l'extension de l'image (formats jpg, png, jpeg, jfif)
            if ($_.Extension -match "^\.(jpg|png|jpeg|jfif)$") {
                #Récupération du nom de l'image et ext si null ou le nom="cover"
                if(($ImageName -eq $null) -or ($_.Name -eq "cover")){
                    $ImageName = $_.Name
                    $ImageExtension = $_.Extension
                }
                
            }
        }

        $c=$c+1

        #Inclue la cover ou non
        if ($IncludeCover -eq "true") {
            #Copie de la musique
            if ($SongName -eq $null) {
                #Chemin complet vers la musique
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                Write-Output "Pas de musique pour : "$SongPath
            }
            else {
                if($ImageName -eq $null){
                    #Nom de la musique (avec format)
                    $DestSongName = $_.Name+$SongExtension

                    #Chemin complet vers la musique
                    $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                    #Chemin de destination complet vers la musique
                    $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                    #On la copie au format d'origine
                    Copy-Item -Path $SongPath -Destination $SongDestPath -Force
                }
                else {
                    #Nom de la musique (avec format)
                    $DestSongName = $_.Name+".mp4"

                    #Chemin complet vers la musique
                    $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                    #Chemin de destination complet vers la musique
                    $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                    #Chemin de la cover
                    $CoverPath = Join-Path -Path $LevelPath -ChildPath $ImageName

                    #On la copie au format mp4 avec la cover
                    # Commande FFmpeg pour créer un fichier MP4
                    if( -not ($AMD -eq $null)){
                        $FFmpegCommand = ".\ffmpeg -loglevel quiet -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -quality 1 -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`""
                    }
                    elseif($Preset -eq "true"){
                        $FFmpegCommand = ".\ffmpeg -loglevel quiet -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`" -preset ultrafast -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`""
                    }
                    else {
                        $FFmpegCommand = ".\ffmpeg -loglevel quiet -y -loop 1 -framerate 1 -i `"$CoverPath`" -i `"$SongPath`" -vf ""scale=if(gte(iw\,2)*2\,iw\,iw-1):if(gte(ih\,2)*2\,ih\,ih-1),pad=iw+1:ih+1:(ow-iw)/2:(oh-ih)/2"" -c:v `"$Codec`"` -c:a aac -b:a 320k -shortest -movflags +faststart `"$SongDestPath`""
                    }
                    
                    try {
                        Write-Host "$c/$MusicNumber - Export de : $DestSongName"

                        Set-Location $targetPath
                        Invoke-Expression $FFmpegCommand
                    } catch {
                        Write-Warning "Erreur lors de la création du fichier $SongName : $_"

                        #Nom de la musique (avec format)
                        $DestSongName = $_.Name+$SongExtension

                        #Chemin complet vers la musique
                        $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                        #Chemin de destination complet vers la musique
                        $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                        #On la copie au format d'origine
                        Write-Host "$c/$MusicNumber - Export de : $DestSongName"
                        Copy-Item -Path $SongPath -Destination $SongDestPath -Force
                    }
                }
            }
        }
        else{
            #Copie de la musique
            if ($SongName -eq $null) {
                #Chemin complet vers la musique
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                Write-Output "Pas de musique pour : "$SongPath
            }
            else {
                #Nom de la musique (avec format)
                $DestSongName = $_.Name+$SongExtension

                #Chemin complet vers la musique
                $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

                #Chemin de destination complet vers la musique
                $SongDestPath = Join-Path -Path $DestPath -ChildPath $DestSongName

                #On la copie au format d'origine
                Write-Host "$c/$MusicNumber - Export de : $DestSongName"
                Copy-Item -Path $SongPath -Destination $SongDestPath -Force
            }
        }
    }
}

Write-Host "Execution terminée"
