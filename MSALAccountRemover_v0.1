#!/bin/bash
#Written by Ben Whitis - 12/7/2023

#Will remove duplicate accounts identified by https://github.com/benwhitis/Jamf_Conditional_Access/blob/main/DuplicateMSALAccountEA
#After running, the machine needs to reboot to recreate the local items keychain
#The user will have one last prompt to sign in to jamfAAD. Subsequent gatherAADInfos should not prompt interactively

#get user
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
#get user home directory
userHome=$(dscl . read "/Users/$loggedInUser" NFSHomeDirectory | awk -F ' ' '{print $2}')
#Get UUID of machine:
UUID=$(system_profiler SPHardwareDataType | awk '/UUID/ {print $3}')
#Delete local items keychain
rm -r $userHome/Library/Keychains/$UUID
