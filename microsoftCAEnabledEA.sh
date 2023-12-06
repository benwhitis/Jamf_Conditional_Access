#!/bin/bash
#Written by Ben Whitis 11/29/2023

mCAE=$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist microsoftCAEnabled)

echo "<result>$mCAE</result>"
