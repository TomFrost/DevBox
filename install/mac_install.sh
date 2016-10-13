#!/bin/sh
###############################################################
#
# Copyright (c) 2016 TechnologyAdvice, LLC
# See LICENSE.txt for software license details.
#
# Portions taken from the fantastic docker-machine-nfs,
# which is Copyright 2015 Toni Van de Voorde (MIT). Find it
# here: https://github.com/adlogix/docker-machine-nfs
#
###############################################################

if [ -z "$MACHINE_NAME" ]; then
  MACHINE_NAME=devbox
fi

EVENTBRIDGE_INSTALL_URL="https://raw.githubusercontent.com/TechnologyAdvice/fs_eventbridge/master/scripts/boot2docker_install.sh"
FS_SCRIPT_PATH="/tmp/fs_install.sh"
SHELLCONF_START="## BEGIN DEVBOX CONFIG"
SHELLCONF_END="## END DEVBOX CONFIG"
SHELLCONF_TMP="${HOME}/.devbox_tmp"

hello() {
  cat <<EOF
This script will configure a Mac running the latest version of macOS to run the
standard TechnologyAdvice development environment. This script strives to be
idempotent: it will check for the end result before completing an action meant
to enact that result. This means that while this script may, for example, install
Node.js from Homebrew, it will not if Node.js has been previously installed by
any other means.

The actions this script will take:
- Install Homebrew
- Install the latest stable Node.js/NPM
- Globally install DevLab from NPM
- Globally install fsbridge from NPM
- Install docker and docker-machine
- Install xhyve and the xhyve driver for docker-machine
- Create a docker-machine named "$MACHINE_NAME" (change this by setting the
  MACHINE_NAME env var)
- Reconfigure the docker VM to mount volumes using NFS (uses docker-machine-nfs)
- Enable file system event streaming on the docker VM (uses fs_eventbridge)

Root access may be required for some of the above. You will be prompted for the
password during the process if this is necessary.

EOF
  if [ "$1" != "--noprompt" ]; then
    read -p "Press Enter to proceed, or CTRL+C to cancel. "
  fi
}

echoError() {
  echo "\033[0;31mFAIL\n\n$1 \033[0m"
}

echoWarn() {
  echo "\033[0;33m$1 \033[0m"
}

echoSuccess() {
  echo "\033[0;32m$1 \033[0m"
}

echoInfo() {
  printf "\033[1;34m[INFO] \033[0m%-62s" "$1"
}

checkForExec() {
  echoInfo "Checking for $1 ..."

  if type $1 >/dev/null 2>&1; then
    echoSuccess "Found"
    return 0
  else
    echoWarn "Not Found"
    return 1
  fi
}

installBrew() {
  echoInfo "Installing brew ..."
  echo #EMPTY_LINE
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  if [ "$?" -ne "0" ]; then
    echoError "Failed to install brew. Please install manually, then run this script again."
    exit 1
  fi
}

installPackage() {
  echoInfo "Installing $1 via brew ..."
  echo #EMPTY_LINE
  brew install $1
  if [ "$?" -ne "0" ]; then
    echoError "Failed to install $1. Please correct errors, then run this script again."
    exit 2
  else
    echoSuccess "Successfully installed $1."
    echo #EMPTY_LINE
  fi
}

installNPMPackage() {
  echoInfo "Installing $1 from NPM ..."
  npm install -g $1
  if [ "$?" -ne "0" ]; then
    echoError "Failed to install $1. Please correct errors, then run this script again."
    exit 3
  else
    echoSuccess "Successfully installed $1."
    echo #EMPTY_LINE
  fi
}

safeInstall() {
  if ! checkForExec $1; then
    installPackage $1
  fi
}

getRealPath() {
  FILEPATH=`which $1`
  FILEDIR=`dirname $FILEPATH`
  LINKPATH=`readlink $FILEPATH`
  if [ -n "$LINKPATH" ]; then
    if [[ "${LINKPATH:0:1}" == "/" ]]; then
      echo $LINKPATH
    else
      echo ${FILEDIR}/${LINKPATH}
    fi
  else
    echo $FILEPATH
  fi
}

checkSetuid() {
  echoInfo "Checking for setuid bit on $1 ..."
  REALPATH=`getRealPath $1`
  IS_SUID=`ls -l $REALPATH | grep "^...s"`
  if [ -n "$IS_SUID" ]; then
    echoSuccess "Set"
    return 0
  else
    echoWarn "Not Set"
    return 1
  fi
}

setSetuid() {
  echoInfo "Setting root owner and setuid bit on $1 ..."
  echo #EMPTY_LINE
  echoWarn " !!! Sudo will be necessary to set root permissions on $1 !!!"
  REALPATH=`getRealPath $1`
  sudo chown root:wheel $REALPATH
  RES_A=$?
  sudo chmod u+s $REALPATH
  RES_B=$?
  if [ "$RES_A" -eq "0" ] && [ "$RES_B" -eq "0" ]; then
    echoSuccess "Done"
    echo #EMPTY_LINE
  else
    echoError "Unable to change permissions. Please correct and run this script again."
    exit 4
  fi
}

checkMachineExists() {
  echoInfo "Checking if $1 machine exists ..."
  if docker-machine status $1 > /dev/null 2>&1; then
    echoSuccess "Exists"
    return 0
  else
    echoWarn "Not Found"
    return 1
  fi
}

createMachine() {
  echoInfo "Creating docker-machine $1 ..."
  echo #EMPTY_LINE
  docker-machine create --driver xhyve $1
  if [ "$?" -eq "0" ]; then
    echoSuccess "Machine '$1' created successfully"
  else
    echoError "Failed creating machine '$1'. Please correct and run this script again."
    exit 5
  fi
}

checkMachineRunning() {
  echoInfo "Checking that machine $1 is running ..."
  RUNNING=`docker-machine status $1`
  if [ "$RUNNING" == "Running" ]; then
    echoSuccess "Running"
    return 0
  else
    echoWarn "Not Running"
    return 1
  fi
}

startMachine() {
  echoInfo "Starting machine $1 ..."
  echo #EMPTY_LINE
  docker-machine start $1
  if [ "$?" -eq "0" ]; then
    echoSuccess "Machine '$1' started successfully"
  else
    echoError "Failed starting machine '$1'. Please correct and run this script again."
    exit 5
  fi
}

installNFS() {
  echoInfo "Running docker-machine-nfs ..."
  echo #EMPTY_LINE
  docker-machine-nfs $1
  if [ "$?" -eq "0" ]; then
    echoSuccess "docker-machine-nfs has run successfully"
    echo #EMPTY_LINE
  else
    echoError "docker-machine-nfs failed. Please correct and run this script again."
    exit 6
  fi
}

installEventBridge() {
  echoInfo "Downloading FS-EventBridge installer ..."
  curl -s $EVENTBRIDGE_INSTALL_URL -o $FS_SCRIPT_PATH > /dev/null 2>&1
  if [ "$?" -gt "1" ]; then
    echoError "Failed to download FS-EventBridge installer. Is Github down?"
    exit 7
  fi
  echoSuccess "Done"
  echoInfo "Running FS-EventBridge installer on $1 ..."
  eval $(docker-machine env $1)
  echo #EMPTY_LINE
  sh $FS_SCRIPT_PATH --noprompt
  if [ "$?" -eq "0" ]; then
    echoSuccess "FS-Eventbridge has been installed successfully"
    echo #EMPTY_LINE
  else
    echoError "The FS-EventBridge installer has failed. Please correct and run this script again."
    exit 9
  fi
}

writeLaunchAgent() {
  echoInfo "Writing LaunchAgent ..."
  AGENT_PATH=${HOME}/Library/LaunchAgents/com.docker.machine.${1}.plist
  cat << EOF > $AGENT_PATH
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>${PATH}</string>
    </dict>
    <key>Label</key>
    <string>com.docker.machine.${1}</string>
    <key>ProgramArguments</key>
    <array>
    <string>$(which tmux)</string>
      <string>-c</string>
      <string>$(which docker-machine) start ${1}; exit</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
EOF
  launchctl load $AGENT_PATH > /dev/null 2>&1
  echoSuccess "Done"
}

checkShell() {
  if echo $SHELL | grep "/$1\$" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

getShellConfigFile() {
  if checkShell zsh; then
    echo "${HOME}/.zshrc"
  elif checkShell bash; then
    echo "${HOME}/.profile"
  fi
}

getShellConfigLines() {
  cat <<EOF

$SHELLCONF_START
eval \$(docker-machine env $1 2> /dev/null)
export FS_EVENTBRIDGE_PORT=65056
$SHELLCONF_END
EOF
}

userDoShellConfig() {
  echo #EMPTY_LINE
  echoWarn "!!! Audience participation required !!!"
  echoWarn "Please add the following lines to your shell's config file:"
  getShellConfigLines $1
  echo #EMPTY_LINE
  echoWarn "Continuing with the script in 3 seconds. Remember to scroll back here!"
  echo #EMPTY_LINE
  sleep 3
}

writeShellConfig() {
  echoInfo "Writing shell config ..."
  FILE=`getShellConfigFile`
  if [ -z "$FILE" ]; then
    echoWarn "Cannot determine config file"
    userDoShellConfig
  else
    touch $FILE
    sed "/^$SHELLCONF_START\$/,/^$SHELLCONF_END\$/d" $FILE > $SHELLCONF_TMP
    cat << EOF > $FILE
$(cat $SHELLCONF_TMP)
$(getShellConfigLines $1)

EOF
    RES=$?
    rm -f $SHELLCONF_TMP
    if [ "$RES" -gt "0" ]; then
      echoWarn "Failed"
      userDoShellConfig
    else
      echoSuccess "Done"
    fi
  fi
}

donezo() {
  echo #EMPTY_LINE
  echoSuccess "----------------------------------"
  echo #EMPTY_LINE
  echoSuccess " Install complete!"
  echo #EMPTY_LINE
  echoSuccess " Open a new terminal window or"
  echoSuccess " source your shell config file to"
  echoSuccess " start using Docker right away."
  echo #EMPTY_LINE
  echoSuccess "----------------------------------"
  echo #EMPTY_LINE
}

# Begin execution
hello $1
checkForExec brew || installBrew
safeInstall node
checkForExec lab || installNPMPackage devlab
checkForExec fsbridge || installNPMPackage fsbridge
safeInstall docker
safeInstall docker-machine
safeInstall xhyve
safeInstall docker-machine-driver-xhyve
safeInstall docker-machine-nfs
safeInstall tmux
checkSetuid docker-machine-driver-xhyve || setSetuid docker-machine-driver-xhyve
checkMachineExists $MACHINE_NAME || createMachine $MACHINE_NAME
checkMachineRunning $MACHINE_NAME || startMachine $MACHINE_NAME
installNFS $MACHINE_NAME
installEventBridge $MACHINE_NAME
writeLaunchAgent $MACHINE_NAME
writeShellConfig $MACHINE_NAME
donezo

