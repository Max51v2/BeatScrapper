#!/bin/sh

#Check if apt is installed
if [ -f "/usr/bin/apt" ]
then
    pwd
    #pwsh -ExecutionPolicy Bypass -File "[Chemin Téléchargement]\BeatScrapper\BeatScrapper.ps1" $Host.Name
else
    echo "Unsuported OS"
fi