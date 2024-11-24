$BSPath = "C:\Program Files (x86)\Steam\steamapps\common\Beat Saber\Beat Saber_Data\CustomLevels"
$DestPath = "C:\Users\Maxime\Downloads\test"

Get-ChildItem -Path $BSPath -Directory | ForEach-Object{

    $LevelPath = Join-Path -Path $BSPath -ChildPath $_.Name

    Get-ChildItem -Path $LevelPath | ForEach-Object {
        if ($_.Extension -ieq ".egg") {
            $SongName = $_.Name
            $Extension = $_.Extension
        }

        # Vérifier les fichiers avec extension .wav
        if ($_.Extension -ieq ".wav") {
            $SongName = $_.Name
            $Extension = $_.Extension
        }
    }

    $SongName2 = $_.Name+$Extension

    $SongPath = Join-Path -Path $LevelPath -ChildPath $SongName
    $SongDestPath = Join-Path -Path $DestPath -ChildPath $SongName2

    Copy-Item -Path $SongPath -Destination $SongDestPath -Force
}