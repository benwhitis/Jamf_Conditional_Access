#!/bin/bash
# Written by Ben Whitis 10/23/2023
# Updated 1/16/2024

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
#get user home directory
userHome=$(dscl . read "/Users/$loggedInUser" NFSHomeDirectory | awk -F ' ' '{print $2}')
#Check if wpj key is present
WPJKey=$(security dump "$userHome/Library/Keychains/login.keychain-db" | grep MS-ORGANIZATION-ACCESS)
if [ ! -z "$WPJKey" ]
    then
    #check if jamfAAD plist exists
    plist="$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist"
    if [ ! -f "$plist" ]; then
        #plist doesn't exist
        echo "registration is incomplete"
        exit 1
    fi
    #enable recurring gatherAADInfo
    su -l $loggedInUser -c "/usr/bin/defaults write ~/Library/Preferences/com.jamf.management.jamfAAD.plist have_an_Azure_id -bool true"
    #reset timer to force recurring gatherAADInfo
    su -l $loggedInUser -c "/usr/bin/defaults write ~/Library/Preferences/com.jamf.management.jamfAAD.plist last_aad_token_timestamp 0"
    #run recurring gatherAADInfo
    su -l $loggedInUser -c "/Library/Application\ Support/JAMF/Jamf.app/Contents/MacOS/Jamf\ Conditional\ Access.app/Contents/MacOS/Jamf\ Conditional\ Access gatherAADInfo -recurring"
    exit 0
fi
echo "no WPJ key found"
exit 1
