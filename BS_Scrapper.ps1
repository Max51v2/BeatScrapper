#Chemin d'accès des maps BS
$BSPath = "C:\Program Files (x86)\Steam\steamapps\common\Beat Saber\Beat Saber_Data\CustomLevels"

#Fichier où les musiques seront transferées
$DestPath = "C:\Users\Maxime\Downloads\test"

#Listage des maps
Get-ChildItem -Path $BSPath -Directory | ForEach-Object{

    #Chemin de la map
    $LevelPath = Join-Path -Path $BSPath -ChildPath $_.Name

    #Listage du contenu de la map
    Get-ChildItem -Path $LevelPath | ForEach-Object {
        #Récupération du nom et de l'extension de la musique (format egg)
        if ($_.Extension -ieq ".egg") {
            $SongName = $_.Name
            $Extension = $_.Extension
        }

        #Récupération du nom et de l'extension de la musique (format wav)
        if ($_.Extension -ieq ".wav") {
            $SongName = $_.Name
            $Extension = $_.Extension
        }
    }

    #Nom de la musique (avec format)
    $SongName2 = $_.Name+$Extension

    #Chemin complet vers la musique
    $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName

    #Chemin de destination complet vers la musique
    $SongDestPath = Join-Path -Path $DestPath -ChildPath $SongName2

    #Copie de la musique
    Copy-Item -Path $SongPath -Destination $SongDestPath -Force
}
