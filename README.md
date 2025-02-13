EN :
If the text doesn't display properly, try to open it in the project and click on "Raw"

WARNING :
You should never run a PowerShell script until you have read it made sure it is safe to do so !
VirusTotal analysis : 
  - BeatScrapper.ps1 : https://www.virustotal.com/gui/file/f6b77ce7329e68bc58a761c86a5ea4ba6f2e5273f7af6b3d03c5458b4e25a9a0
  - Init.sh : https://www.virustotal.com/gui/file/340ab5ae77212d5a2b5eb4f939a40b2af612904bb4dc0245786b425ba55d250a

I) Presentation
 This project's purpose is to export Beat Saber maps' songs in a specified folder.
 Functionnalities :
  - Export songs from multiple maps folders
  - Export to EGG or your prefered video format with the cover included in the video
  - Choose your own codec
  - ✨smooth animations in real time : progression bar + history of latest songs exported + activity indicator (spinner) ✨
   => fit in the entirety of the PowerShell window
 This script only works on Windows and Linux (Debian based)
 Demonstration : https://www.youtube.com/watch?v=YthqL0C6YyU

II) How to execute the project ?
  a) Clone the repository or download it (releases tab)
  b) Change the script options (at the begining of the script) available here "[project path]\BeatScrapper.ps1"
  Windows :
      powershell.exe -ExecutionPolicy Bypass -File "[Download Path]\BeatScrapper\BeatScrapper.ps1" $Host.Name
    Linux (Debian based) :
      sudo chmod 777 [Download Path]/BeatScrapper/Init.sh
      sudo [Download Path]/BeatScrapper/Init.sh

III) Who should you contact if you have a question or an issue ?
 - Maxime VALLET



FR :
En cas de problèmes d'affichage, merci d'ouvrir la doc depuis le projet et de séléctionner l'affichage de type "Raw"

ATTENTION :
N'exécutez jamais de script PowerShell avant d'avoir lu son contenu et que vous ayez déterminé que cela soit sans danger !
Analyse VirusTotal : 
  - BeatScrapper.ps1 : https://www.virustotal.com/gui/file/f6b77ce7329e68bc58a761c86a5ea4ba6f2e5273f7af6b3d03c5458b4e25a9a0
  - Init.sh : https://www.virustotal.com/gui/file/340ab5ae77212d5a2b5eb4f939a40b2af612904bb4dc0245786b425ba55d250a

I) Présentation
 Ce projet permet d'exporter les musiques des maps de Beat Saber dans un dossier spécifié (exemple dans le projet).
 Fonctionnalités :
  - Export des musiques depuis plusieur dossiers contenant des maps
  - Export au format EGG ou à votre format vidéo préféré contenant la cover en fond
  - Choisissez votre propre codec
  - ✨animations fluides et en temps réel : barre de progression + historique des dernière musiques exportées + indicateur d'activité (spinner) ✨
   => fit in the entirety of the PowerShell window
 Ce script ne fonctionne que sur Windows et Linux (OS basé sur Debian)
 Démonstration : https://www.youtube.com/watch?v=YthqL0C6YyU

II) Comment exécuter le projet ?
  a) Clonez le répertoire ou téléchargez-le (onglet releases)
  b) Changez les options du script (au début du script) disponible ici "[chemin du project]\BeatScrapper.ps1"
  c) Lancez le script
    Windows :
      powershell.exe -ExecutionPolicy Bypass -File "[Chemin Téléchargement]\BeatScrapper\BeatScrapper.ps1" $Host.Name
    Linux (OS basé sur Debian) :
      sudo chmod 777 [Chemin Téléchargement]/BeatScrapper/Init.sh
      sudo [Chemin Téléchargement]/BeatScrapper/Init.sh

III) Qui contacter en cas de question ?
 - Maxime VALLET
