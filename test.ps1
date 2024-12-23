$CLIWidth = $Host.UI.RawUI.WindowSize.Width - 1
$CLIHeight = $Host.UI.RawUI.WindowSize.Height - 2

$FullMessage = "H "

$Char=0
while ($Char -le $CLIWidth) {
    $FullMessage = $FullMessage+"a"

    $Char = $Char+1
}

$MessageType = $FullMessage.Substring(0, 1)
$Message = $FullMessage.Substring(2)

$Line=0
while ($Line -le $CLIHeight) {
    if($MessageType -eq "H"){
        Write-Host "$Message"
    }
    elseif ($MessageType -eq "W") {
        Write-Warning "$Message"
    }

    $Line = $Line+1
}