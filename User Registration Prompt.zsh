#!/bin/zsh --no-rcs
# shellcheck disable=SC2034,SC2309

####################################################################################################
#
# User Registration Prompt
#
####################################################################################################
#
# HISTORY
#
#   Version 1.0.0, 08.15.2022, Ben Whitis (@benwhitis)
#   - Created script to prompt user via osascript
#
#   Verison 2.0.0, 06.06.2023, Robert Schroeder (@robjschroeder)
#   - Added support for swiftDialog
#   - Added client side logging and Pre-Flight Checks
#
#   Version 2.0.1, 01.24.2024, Robert Schroeder (@robjschroeder)
#   - Updated pre-flight checks for swiftDialog (Monterey or higher required)
#   - Changed script to zsh for array use with dialog
#   - Added personalized salutation based on computer's current time
#
#  Version 2.0.2, 02.21.2024, Ben Whitis (@benwhitis)
#  - Addressed an issue where some computers were experiencing errors during the swift dialog check process, resulting in a `= not found` in the logs (Issue #2)
#
####################################################################################################

####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version and Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="2.0.2"
scriptFunctionalName="AAD User Registration Prompt"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

scriptLog="${4:-"/var/log/com.company.log"}"                 # Parameter 4: Script Log Location [ /var/log/com.company.log ] (i.e., Your organization's default location for client-side logs)
useSwiftDialog="${5:-"true"}"                                # Parameter 5: Triggers to use swiftDialog rather than osascript [ true (default) | false ]
useOverlayIcon="${6:-"true"}"                                # Parameter 6: Toggles swiftDialog to use an overlay icon [ true (default) | false ]
jamfProPolicyID="${7:-"1"}"                                  # Parameter 7: The Jamf Pro ID for the device compliance registration policy

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Various Feature Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Message variables
title="Device Compliance Registration"
message="Please finish setting up your computer by running the Device Compliance Registration policy in Self Service. Click OK to get started!"
icon="https://d8p1x3h4xd5gq.cloudfront.net/59822132ca753d719145cc4c/public/601ee87d92b87d67659ff2f2.png"
helpmessage="Device Compliance is necessary to ensure that your device meets specific security standards and protocols, helping protect and maintain the integrity of your data."
timer="120"

# swiftDialog Variables
swiftDialogMinimumRequiredVersion="2.3.2.4726"					# Minimum version of swiftDialog required to use workflow
dialogBinary="/usr/local/bin/dialog"
dialogCommandFile=$( /usr/bin/mktemp -u /var/tmp/dialogCommand.XXX )

# Create `overlayicon` from Self Service's custom icon (thanks, @meschwartz!)
if [[ "$useOverlayIcon" == "true" ]]; then
  xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p > /var/tmp/overlayicon.icns
  overlayicon="/var/tmp/overlayicon.icns"
else
  overlayicon=""
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System, Computer Model Name, etc.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$( sw_vers -productVersion )
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
exitCode="0"

####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
  touch "${scriptLog}"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
  echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Current Logged-in User Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function currentLoggedInUser() {
  loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
  updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User: ${loggedInUser}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# ${scriptFunctionalName} (${scriptVersion})\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
  updateScriptLog "PRE-FLIGHT CHECK: This script must be run as root; exiting."
  exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm Dock is running / user is at Desktop
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

until pgrep -q -x "Finder" && pgrep -q -x "Dock"; do
  updateScriptLog "PRE-FLIGHT CHECK: Finder & Dock are NOT running; pausing for 1 second"
  sleep 1
done

updateScriptLog "PRE-FLIGHT CHECK: Finder & Dock are running; proceeding …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System Version Big Sur or later
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Since swiftDialog requires at least macOS 11 Big Sur, first confirm the major OS version
if [[ "${osMajorVersion}" -ge 12 ]] ; then
  
  updateScriptLog "PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; proceeding ..."
  
else
  
  # The Mac is running an operating system older than macOS 12 Monterey; exit with error
  updateScriptLog "PRE-FLIGHT CHECK: swiftDialog requires at least macOS 12 Monterey and this Mac is running ${osVersion} (${osBuild}), proceed with osascript."
  useSwiftDialog="false"
  
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Ensure computer does not go to sleep (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Caffeinating this script (PID: $$)"
caffeinate -dimsu -w $$ &
scriptPID="$$"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Logged-in System Accounts
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Check for Logged-in System Accounts …"
currentLoggedInUser

counter="1"

until { [[ "${loggedInUser}" != "_mbsetupuser" ]] || [[ "${counter}" -gt "180" ]]; } && { [[ "${loggedInUser}" != "loginwindow" ]] || [[ "${counter}" -gt "30" ]]; } ; do
  
  updateScriptLog "PRE-FLIGHT CHECK: Logged-in User Counter: ${counter}"
  currentLoggedInUser
  sleep 2
  ((counter++))
  
done

loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print toupper(substr($0,1,1))substr($0,2)}' )
loggedInUserID=$( id -u "${loggedInUser}" )
updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User First Name: ${loggedInUserFirstname}"
updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User ID: ${loggedInUserID}"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate/install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #



function dialogInstall() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    updateScriptLog "Installing swiftDialog..."

    # Create a temporary working directory
    workDirectory=$( basename "$0" )
    tempDirectory=$( mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [[ "$expectedDialogTeamID" == "$teamID" ]]; then
        /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
        sleep 2
        dialogVersion=$( /usr/local/bin/dialog --version )
        updateScriptLog "swiftDialog version ${dialogVersion} installed; proceeding..."
    else
        # Display a so-called "simple" dialog if Team ID fails to validate
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "'"${scriptFunctionalName}"': Error" buttons {"Close"} with icon caution'
        exitCode="1"
        quitScript
    fi

    # Remove the temporary working directory when done
    rm -Rf "$tempDirectory"

}

function dialogCheck() {

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
        updateScriptLog "swiftDialog not found. Installing..."
        dialogInstall
    else
        dialogVersion=$(/usr/local/bin/dialog --version)
        if [[ "${dialogVersion}" < "${swiftDialogMinimumRequiredVersion}" ]]; then
            updateScriptLog "swiftDialog version ${dialogVersion} found but swiftDialog ${swiftDialogMinimumRequiredVersion} or newer is required; updating..."
            dialogInstall
        else
            updateScriptLog "swiftDialog version ${dialogVersion} found; proceeding..."
        fi
    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
  if [[ "${useSwiftDialog}" == "true" ]]; then
    updateScriptLog "PRE-FLIGHT CHECK: swiftDialog is not found and is configured to be used..."
    dialogCheck
  fi
else
  updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $(/usr/local/bin/dialog --version) found; proceeding..."
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Complete"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# General Functions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function killProcess() {

    process="$1"
    if process_pid=$( pgrep -a "${process}" 2>/dev/null ) ; then
        updateScriptLog "Attempting to terminate the '$process' process …"
        updateScriptLog "(Termination message indicates success.)"
        kill "$process_pid" 2> /dev/null
        if pgrep -a "$process" >/dev/null ; then
            updateScriptLog "'$process' could not be terminated."
        fi
    else
        updateScriptLog "The '$process' process isn't running."
    fi

}

function quitScript() {
  updateScriptLog "QUIT SCRIPT: Exiting …"
  
  # Stop `caffeinate` process
  updateScriptLog "QUIT SCRIPT: De-caffeinate …"
  killProcess "caffeinate"
  
  # Remove overlayicon
  if [[ -e ${overlayicon} ]]; then
    updateScriptLog "QUIT SCRIPT: Removing ${overlayicon} …"
    rm "${overlayicon}"
  fi
  
  # Remove welcomeCommandFile
  if [[ -e ${dialogCommandFile} ]]; then
    updateScriptLog "QUIT SCRIPT: Removing ${dialogCommandFile} …"
    rm "${dialogCommandFile}"
  fi
  
  exit $exitCode
}

function promptUser() {
  updateScriptLog "${scriptFunctionalName}: Prompting the user to execute policy ID: $jamfProPolicyID"

  greeting=$((){print Good ${argv[2+($1>11)+($1>18)]}} ${(%):-%D{%H}} morning afternoon evening)

  
  if [[ "$useSwiftDialog" == "true" ]]; then
    updateScriptLog "${scriptFunctionalName}: Prompting user using swiftDialog..."

    # Create the deferrals available dialog options and content
    deferralDialogContent=(
        --title "$title"
        --message "$greeting $loggedInUserFirstname! $message"
        --helpmessage "$helpmessage"
        --icon "$icon"
        --iconsize 180
        --overlayicon "$overlayicon"
        --timer "$timer"
        --button1text "Ok"
    )

    deferralDialogOptions=(
        --position center
        --moveable
        --small
        --ignorednd
        --quitkey k
        --titlefont size=28
        --messagefont size=18
        --commandfile "$dialogCommandFile"
    )
    
    
    "$dialogBinary" "${deferralDialogContent[@]}" "${deferralDialogOptions[@]}"
            
    returnCode=$?
    
    case ${returnCode} in 
      
      0) updateScriptLog "${scriptFunctionalName}: ${loggedInUser} clicked OK; "
        su - "${loggedInUser}" -c "/usr/bin/killall Self\ Service"
        su - "${loggedInUser}" -c "/usr/bin/open \"jamfselfservice://content?entity=policy&id=$jamfProPolicyID&action=view\""
      ;;
      2) updateScriptLog "${scriptFunctionalName}: ${loggedInUser} clicked Button2; "
      ;;
      4) updateScriptLog "${scriptFunctionalName}: ${loggedInUser} allowed timer to expire"
      ;;
      *) updateScriptLog "${scriptFunctionalName}: Something else happened; swiftDialog Return Code: ${returnCode};"
      ;;
      
    esac
    
  else
    updateScriptLog "${scriptFunctionalName}: Prompting user using osascript..."
    
    if [[ "$useOverlayIcon" == true ]]; then
      updateScriptLog "${scriptFunctionalName}: Using icon..."
    answer=$( /usr/bin/osascript << EOF
      button returned of (display dialog "${message}" buttons {"OK"} default button 1 with icon POSIX file "$overlayicon")
EOF
      )
    else
      updateScriptLog "${scriptFunctionalName}: Not using icon..."
    answer=$( /usr/bin/osascript << EOF
      button returned of (display dialog "${message}" buttons {"OK"} default button 1)
EOF
      )
    fi
    
      updateScriptLog "${scriptFunctionalName}: $loggedInUser clicked $answer"
    
      if [[ $answer == "OK" ]]; then
      su "$loggedInUser" -c "/usr/bin/killall Self\ Service"
      su "$loggedInUser" -c "/usr/bin/open \"jamfselfservice://content?entity=policy&id=$jamfProPolicyID&action=view\""
      fi
    
  fi
}

promptUser

quitScript
