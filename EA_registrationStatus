#!/bin/bash
#Written by Ben Whitis - 08/11/2022
#Updated 11/29/2023 - use dscl to identify user home directory for scenarios where loggedInUser is an alias
#Updated 10/10/2024 - added support for platformSSO referencing @robjschroeder's EA

#get user
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
#get user home directory
userHome=$(dscl . read "/Users/$loggedInUser" NFSHomeDirectory | awk -F ' ' '{print $2}')

#check if registered via PSSO: 
platformStatus=$( su $loggedInUser -c "app-sso platform -s" | grep 'registration' | /usr/bin/awk '{ print $3 }' | sed 's/,//' )
if [[ "${platformStatus}" == "true" ]]; then
  #Check if jamfAAD registered too
  psso_AAD_ID=$(defaults read  "$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist" have_an_Azure_id 2>/dev/null)
  if [[ $psso_AAD_ID -eq "1" ]]; then
    #jamfAAD ID exists
    echo "<result>Registered with Platform SSO - $userHome</result>"
    exit 0
  fi
  #PSSO registered but not jamfAAD registered
  echo "<result>Platform SSO registered but AAD ID not acquired for user home: $userHome</result>"
  exit 0
fi

#check if wpj private key is present
WPJKey=$(security dump "$userHome/Library/Keychains/login.keychain-db" | grep MS-ORGANIZATION-ACCESS)
if [ ! -z "$WPJKey" ]
then
  #WPJ key is present
  #check if jamfAAD plist exists
  plist="$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist"
  if [ ! -f "$plist" ]; then
    #plist doesn't exist
      echo "<result>WPJ Key present, JamfAAD PLIST missing from user home: $userHome</result>"
      exit 0
  fi

  #PLIST exists. Check if jamfAAD has acquired AAD ID
  AAD_ID=$(defaults read  "$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist" have_an_Azure_id)
  if [[ $AAD_ID -eq "1" ]]; then
    #jamfAAD ID exists
    echo "<result>Registered - $userHome</result>"
    exit 0
  fi

  #WPJ is present but no AAD ID acquired:
  echo "<result>WPJ Key Present. AAD ID not acquired for user home: $userHome</result>"
  exit 0
fi

#no wpj key
echo "<result>Not Registered for user home $userHome</result>"
