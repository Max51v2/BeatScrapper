#!/bin/bash
#Author : Maxime VALLET

clear

#Check if apt is installed
if [ -f "/usr/bin/apt" ]
then
    clear

    echo "Checking if dependancies are installed"

    apt-get update 

    #Check if PowerShell is installed
    PWSH=$(which pwsh)

    #Check if FFmpeg is installed
    ffmpeg=$(which ffmpeg)

    #Check if we skip the prompt to install dependancies
    SkipPrompt="false"
    if [ "$PWSH" != "" ] && [ "$ffmpeg" != "" ]
    then
        SkipPrompt="true"
    fi

    clear

    option="undetermined"
    c=0

    #Tant que l'on a pas une option valide, on redemande à l'utilisateur d'en saisir une
    while [ "$option" != "Y" ] && [ "$option" != "y" ] && [ "$option" != "y" ] && [ "$SkipPrompt" = "false" ]
    do
        #Stop the script if user typed "cancel"
        if [ "$option" = "N" ] || [ "$option" = "n" ]
        then
            clear

            #Stop the script
            exit 1
        fi

        clear

        if [ "$c" -ge 1 ]
        then
            echo "Wrong input : \"$option\""

            echo
        fi

        echo "Running BeatScrapper.ps1 require the following daemons : powershell and FFmpeg"
        echo "Do you want to proceed with the installation of these daemons (Sources : PowerShell => Microsoft's website / FFmpeg : APT) ? [Y | N]"

        echo

        sleep 1

        #Lecture de l'entrée utilisateur
        read  -n 1 -p "Option :" option

        c=$(($c+1)) 
    done


    clear

    apt-get update 

    clear


    #If powershell isn't installed
    if [ "$PWSH" = "" ]
    then
        echo "Installing PowerShell"

        # Install pre-requisite packages.
        sudo apt-get install -y wget

        # Download the PowerShell package file
        wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell_7.4.6-1.deb_amd64.deb

        ###################################
        # Install the PowerShell package
        sudo dpkg -i powershell_7.4.6-1.deb_amd64.deb

        # Resolve missing dependencies and finish the install (if necessary)
        sudo apt-get install -f

        # Delete the downloaded package file
        rm powershell_7.4.6-1.deb_amd64.deb
    fi

    clear

    #If FFmpeg isn't installed
    if [ "$ffmpeg" = "" ]
    then
        echo "Installing FFmpeg"
        sudo apt-get install -y ffmpeg 
    fi


    #Retrive the powershell's script path
    ProjectDirPath=$(echo $0 | sed 's:/[^/]*$::')
    BeatScrapperPWSHScriptPath=$(echo "$ProjectDirPath/BeatScrapper.ps1")

    clear

    #Launch the script
    echo "Launching BeatScrapper.ps1"
    pwsh -ExecutionPolicy Bypass -File $BeatScrapperPWSHScriptPath $Host.Name
else
    echo "Unsuported OS"
fi