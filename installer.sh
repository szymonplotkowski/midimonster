#!/bin/bash

################################################ SETUP ################################################
deps=(libasound2-dev libevdev-dev liblua5.3-dev libjack-jackd2-dev pkg-config libssl-dev gcc make wget git)
user=$(whoami)                  # for bypassing user check replace "$(whoami)" with "root".

tmp_path=$(mktemp -d)           # Repo download path
updater_dir=/etc/midimonster-updater-installer       # Updater download + config path
updater_file=$updater_path/updater.conf                   # 

latest_version=$(curl --silent "https://api.github.com/repos/cbdevnet/midimonster/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
installed_version=$(midimonster --version)

makeargs=all                    # Build args

VAR_DESTDIR=""                  # Unused
VAR_PREFIX="/usr"
VAR_PLUGINS="$VAR_PREFIX/lib/midimonster"
VAR_DEFAULT_CFG="/etc/midimonster/midimonster.cfg"
VAR_EXAMPLE_CFGS="$VAR_PREFIX/share/midimonster"

################################################ SETUP ################################################

############################################## FUNCTIONS ##############################################

INSTALL-DEPS () {           ##Install deps from array "$deps"
for t in ${deps[@]}; do
    if [ $(dpkg-query -W -f='${Status}' $t 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        echo "Installing "$t"";
        apt-get install $t;
        echo "Done.";
    else
        echo ""$t" already installed!"

    fi
done
echo ""
}

INSTALL-PREP () {
(#### Subshell make things like cd $tmp_path easier to revert
    echo "Starting download..."
    git clone https://github.com/cbdevnet/midimonster.git "$tmp_path" # Gets Midimonster   
    echo ""
    echo ""
    echo "Initializing repository..."
    cd $tmp_path
    git init $tmp_path
    echo ""
    
    read -p "Do you want to install the nightly version? (y/n)?" magic      #Asks for nightly version
    case "$magic" in 
    y|Y )   echo "OK! You´re a risky person ;D"
            NIGHTLY=1
            ;;
    n|N )   echo "That´s ok I´ll install the latest stable version ;-)"
            NIGHTLY=0
            ;;
      * )   echo "invalid"
            echo "ABORTING"
            ;;
    esac

    if [ $NIGHTLY != 1 ]; then echo "Finding latest stable version..."; Iversion=$(git describe --abbrev=0); echo "Starting Git checkout to "$Iversion"..."; git checkout -f -q $Iversion; fi # Git checkout if NIGHTLY !=1
    echo "Preparing Done."

 )

    echo ""
    echo ""
    echo ""

    read -e -i "$VAR_PREFIX" -p "PREFIX (Install root directory): " input # Reads VAR_PREFIX
    VAR_PREFIX="${input:-$VAR_PREFIX}"

    read -e -i "$VAR_PLUGINS" -p "PLUGINS (Plugin directory): " input # Reads VAR_PLUGINS
    VAR_PLUGINS="${input:-$VAR_PLUGINS}"

    read -e -i "$VAR_DEFAULT_CFG" -p "Default config path: " input # Reads VAR_DEFAULT_CFG
    VAR_DEFAULT_CFG="${input:-$VAR_DEFAULT_CFG}"

    read -e -i "$VAR_EXAMPLE_CFGS" -p "Example config directory: " input # Reads VAR_EXAMPLE_CFGS
    VAR_EXAMPLE_CFGS="${input:-$VAR_EXAMPLE_CFGS}"

    UPDATER_SAVE

    export PREFIX=$VAR_PREFIX
    export PLUGINS=$VAR_PLUGINS
    export DEFAULT_CFG=$VAR_DEFAULT_CFG
    export DESTDIR=$VAR_DESTDIR
    export EXAMPLES=$VAR_EXAMPLE_CFGS
}

UPDATER-PREP () {
(#### Subshell make things like cd $tmp_path easier to revert


    echo "Starting download..."
    git clone https://github.com/cbdevnet/midimonster.git "$tmp_path" # Gets Midimonster   
    echo ""
    echo ""
    echo "Initializing repository..."
    cd $tmp_path
    git init $tmp_path
    echo ""
    
    read -p "Do you want to install the nightly version? (y/n)?" magic      #Asks for nightly version
    case "$magic" in 
    y|Y )   echo "OK! You´re a risky person ;D"
            NIGHTLY=1
            ;;
    n|N )   echo "That´s ok I´ll install the latest stable version ;-)"
            NIGHTLY=0
            ;;
      * )   echo "invalid"
            echo "ABORTING"
            ;;
    esac

    if [ $NIGHTLY != 1 ]; then echo "Finding latest stable version..."; Iversion=$(git describe --abbrev=0); echo "Starting Git checkout to "$Iversion"..."; git checkout -f -q $Iversion; fi # Git checkout if NIGHTLY !=1
    echo "Done."

 )

    echo ""
    echo ""
    echo ""

    if [ -sf $updater_file ]; then . $updater_file; else echo "Failed to load updater config from $updater_file"     # Checks if updater config file exist and import it(overwrite default values!)

    export PREFIX=$VAR_PREFIX
    export PLUGINS=$VAR_PLUGINS
    export DEFAULT_CFG=$VAR_DEFAULT_CFG
    export DESTDIR=$VAR_DESTDIR
    export EXAMPLES=$VAR_EXAMPLE_CFGS
    echo "Sucessfully imported Updater settings from $updater_file."
}

UPDATER () {
    if [[ $installed_version !=~ $latest_version ]]; else echo "Newest Version is allready installed! ($installed_version)"; ERROR; fi     # PRÜFEN OB DAS FUNKTIONIERT MIT DER NIGHTLY VERSION INSTALLIERT! WELCHE VERSION KOMMT DA RAUS BEI midimonster --version??? passt das?
    UPDATER-PREP
    INSTALL-RUN
    
    echo "Updating updater/installer script in $updater_dir"
    wget "https://raw.githubusercontent.com/cbdevnet/midimonster/master/installer.sh" -O $updater_dir
    chmod +x $updater_dir/installer.sh
    DONE
}

INSTALL-RUN () {                                    # Build
    cd "$tmp_path"
    make clean
    make $makeargs
    make install
}

UPDATER_SAVE () {                                   # Saves file for the auto updater in this script
    rm -rf $updater_dir
    echo "Saving updater to $updater_dir/installer.sh" 
    mkdir -p "$updater_dir"
    wget https://raw.githubusercontent.com/cbdevnet/midimonster/master/installer.sh -O $updater_dir/installer.sh
    echo "creating symlink to updater/installer in /usr/bin/midimonster-updater-installer"
    ln -s "$updater_dir/installer.sh" "/usr/bin/midimonster-updater-installer"
    echo "Exporting updater config to $updater_file"
    printf "VAR_PREFIX=%s\nVAR_PLUGINS=%s\nVAR_DEFAULT_CFG=%s\nVAR_DESTDIR=%s\nVAR_EXAMPLE_CFGS=%s\n" "$VAR_PREFIX" "$VAR_PLUGINS" "$VAR_DEFAULT_CFG" "$VAR_DESTDIR" "$VAR_EXAMPLE_CFGS" > "$updater_file"
}

ERROR () {
    echo "Aborting..."
    CLEAN
    exit 1
}

DONE () {
    echo Done.
    CLEAN
    exit 0
}

CLEAN () {
    echo "Cleaning..."
    rm -rf $tmp_path
}

############################################## FUNCTIONS ##############################################


################################################ Main #################################################
trap ERROR SIGINT SIGTERM SIGKILL
clear

if [ $user != "root" ]; then echo "Installer must be run as root"; ERROR; fi    # Check if $user = root!

if [ $(wget -q --spider http://github.com) $? -eq 0 ]; else echo You need connection to the internet; ERROR ; fi

if [ -e /usr/bin/midimonster ]; else echo "Midimonster binary not found skipping updater."; then UPDATER; fi    # Check if binary /usr/bin/midimonster exist. If yes start updater

INSTALL-DEPS
INSTALL-PREP
echo ""
INSTALL-RUN
DONE