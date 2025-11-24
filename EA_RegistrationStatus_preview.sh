#!/bin/bash
#Written by Ben Whitis - 08/11/2022
#Updated 11/29/2023 - use dscl to identify user home directory for scenarios where loggedInUser is an alias
#Updated 10/10/2024 - added support for platformSSO referencing @robjschroeder's EA
#Updated 10/03/2025 - modified how login keychain is queried, return device ID in result
#Updated 10/03/2025 - added support for 'getPSSOStatus' verb
#Updated 11/24/2025 - switch to 'launchctl asuser' instead of `su -c`

#get user
loggedInUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )
#get user home directory
userHome=$(/usr/bin/dscl . read "/Users/$loggedInUser" NFSHomeDirectory | /usr/bin/awk -F ' ' '{print $2}')

#Check if registered via PSSO/SSOe first
ssoStatus=$(/bin/launchctl asuser $( /usr/bin/id -u $loggedInUser ) /Library/Application\ Support/JAMF/Jamf.app/Contents/MacOS/Jamf\ Conditional\ Access.app/Contents/MacOS/Jamf\ Conditional\ Access getPSSOStatus | /usr/bin/sed -E 's/AnyHashable\(|\)//g' | /usr/bin/tr ',' '\n')
  if [[ $ssoStatus == *"primary_registration_metadata_device_id"* ]]; then
  #Check if jamfAAD registered too
  AAD_ID=$(/usr/bin/defaults read  "$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist" have_an_Azure_id)
  if [[ $AAD_ID -eq "1" ]]; then
    #jamfAAD ID exists, and PSSO/SSOe registered. Return getPSSOStatus results
    echo "<result>Registered - $userHome 
    Details:
    $ssoStatus</result>"
    exit 0
  fi
  #SSOe/PSSO secure enclave registered but not jamfAAD registered
  echo "<result>WPJ Key is in Secure Enclave, but AAD ID not acquired for user home: $userHome</result>"
fi

#Fall back to legacy (Login Keychain) checks
#check if wpj private key is present
WPJKey=$(/bin/launchctl asuser $( /usr/bin/id -u $loggedInUser ) "/usr/bin/security find-certificate -a -Z | /usr/bin/grep -B 9 "MS-ORGANIZATION-ACCESS" | /usr/bin/awk '/\"alis\"<blob>=\"/ {print $NF}' | /usr/bin/sed 's/\"alis\"<blob>=\"//;s/.$//'")
if [ ! -z "$WPJKey" ]
then
  #WPJ key is present
  #check if jamfAAD plist exists
  plist="$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist"
  if [ ! -f "$plist" ]; then
    #plist doesn't exist
      echo "<result>WPJ Key present, JamfAAD PLIST missing from user home: $userHome 
Device ID: $WPJKey</result>"
      exit 0
  fi

  #PLIST exists. Check if jamfAAD has acquired AAD ID
  AAD_ID=$(/usr/bin/defaults read  "$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist" have_an_Azure_id)
  if [[ $AAD_ID -eq "1" ]]; then
    #jamfAAD ID exists
    echo "<result>Registered - $userHome 
Device ID: $WPJKey</result>"
    exit 0
  fi

  #WPJ is present but no AAD ID acquired:
  echo "<result>WPJ Key Present. AAD ID not acquired for user home: $userHome 
Device ID: $WPJKey</result>"
  exit 0
fi

#no wpj key
echo "<result>Not Registered for user home $userHome</result>"
