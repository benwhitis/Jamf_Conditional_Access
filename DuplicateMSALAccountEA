#!/bin/bash
#Written by Ben Whitis 12/06/2023

result=$(log show --style compact --predicate 'subsystem == "com.jamf.management.jamfAAD"' --last 5d | grep "posible for silent token acquire to fail now if the wrong account is picked")
if [[ $result == '' ]]
then
echo "<result>No duplicate accounts found</result>"
else
echo "<result>Multiple accounts found</result>"
fi
