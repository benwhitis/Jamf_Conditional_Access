#!/bin/bash
# copyright 2024, JAMF Software, LLC
# THE SOFTWARE IS PROVIDED "AS-IS," WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.
# IN NO EVENT SHALL JAMF SOFTWARE, LLC OR ANY OF ITS AFFILIATES BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OF OR OTHER DEALINGS IN THE SOFTWARE, 
# INCLUDING BUT NOT LIMITED TO DIRECT, INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL OR PUNITIVE DAMAGES AND OTHER DAMAGES SUCH AS LOSS OF USE, PROFITS, SAVINGS, TIME OR DATA, BUSINESS INTERRUPTION, OR PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES.

# ENVIRONMENTS USING GCC HIGH: Modify the expected Client ID on line 18 before deploying.
# This script does the following: 
# 1: Verify the jamf management framework is ready for the migration from Conditional Access to Device Compliance
# 2: Create a LaunchAgent to call a gatherAADInfo whenever the user logs in (will run immediately if user is already logged in)
# 3: The LaunchAgent and a script it relies on are deleted after the gatherAADInfo has run

### Variables ###

#check jamf management plist for updated client ID
localClientID=$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist microsoftCANativeClientAppId)
#Client ID for "User registration app for device compliance". For GCC High environments, please change the ID to dcf07df3-346f-4f0e-b803-c1f0ea0fb5ae on the line below.
expectedClientID="b03c10a8-71c7-45f9-b44a-3335ab76e970"
#Verify CAEnabled
CAEnabled=$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist microsoftCAEnabled)
#user who is currently logged in
currentUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
#most recent real user to log in (may not currently be logged in)
mostRecentUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/kCGSSessionUserNameKey :/ && ! /root/ && ! /loginwindow/ && ! /_mbsetupuser/ { print $3 }' )
#home of most recent user
userHome=$(/usr/bin/dscl . read "/Users/$mostRecentUser" NFSHomeDirectory | /usr/bin/awk -F ' ' '{print $2}')

### Functions ###

# Verify com.jamfsoftware.jamf.plist has required settings to migrate
function jamfsoftware_settings {
    /bin/echo "Checking management framework..."
    if [[ $localClientID != $expectedClientID ]]; then
        #need to update plist, needs to come from Jamf Pro or we're masking potential issues
        /usr/local/jamf/bin/jamf manage
        #echo to policy log
        /bin/echo "com.jamfsoftware.jamf.plist was not up to date (microsoftCANativeClientAppID)"
    fi
    if [[ $CAEnabled != 1 ]]; then
        #need to update plist, needs to come from Jamf Pro or we're masking potential issues
        /usr/local/jamf/bin/jamf manage
        #echo to policy log
        /bin/echo "com.jamfsoftware.jamf.plist was not up to date (microsoftCAEnabled)."
        /bin/echo "This state may be encountered repeatedly if computers are not in the \"applicable\" smart computer group"
    fi
}       
function make_la {
    /bin/echo "Making launch agent..."
    # Do not modify these two paths
    LA_path="$userHome/Library/LaunchAgents/com.jamf.management.jamfAAD.migrator.plist"
    script_path="$userHome/Library/JamfAADStaging/jamfAAD_migrator.sh"
    #create user-level launch agents directory if it doesn't already exist
    /usr/bin/su -l $mostRecentUser -c "mkdir -p ~/Library/LaunchAgents"
    #create the launch agent
/usr/bin/tee $LA_path << 'EOAGENT' >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.jamf.management.jamfAAD.migrator.plist</string>
    <key>ProgramArguments</key>
    <array>
      <string>sh</string>
      <string>-c</string>
      <string>~/Library/JamfAADStaging/jamfAAD_migrator.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>10</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchOnlyOnce</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/jamfaad.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/jamfaad.log</string>
  </dict>
</plist>
EOAGENT
    /usr/sbin/chown $mostRecentUser:staff "$LA_path"
    /bin/chmod 644 "$LA_path"
    #Create script
    /usr/bin/su -l "$mostRecentUser" -c "mkdir -p \"$userHome/Library/JamfAADStaging\""
/usr/bin/tee $script_path << 'EOSCRIPT' >/dev/null
#!/bin/bash
sleep 30
/Library/Application\ Support/JAMF/Jamf.app/Contents/MacOS/Jamf\ Conditional\ Access.app/Contents/MacOS/Jamf\ Conditional\ Access gatherAADInfo
rm ~/Library/LaunchAgents/com.jamf.management.jamfAAD.migrator.plist
rm -r ~/Library/JamfAADStaging
EOSCRIPT
    /bin/chmod 555 $script_path
    /usr/sbin/chown $mostRecentUser:staff "$script_path"
    #check if the user is logged in to load the agent:
    if [[ "$currentUser" == "loginwindow" ]] || [[ "$currentUser" == "_mbsetupuser" ]] || [[ "$currentUser" == "root" ]] || [[ -z "$currentUser" ]]; then
        #user is not logged in
        /bin/echo "User is not logged in. Launch Agent was created and will load when the user logs in."
        exit 0
    fi
    /bin/echo "User is logged in. Loading launch agent for user $mostRecentUser"
    userID=$(/usr/bin/id -u $mostRecentUser)
    /usr/bin/su -l $mostRecentUser -c "launchctl unload ~/Library/LaunchAgents/com.jamf.management.jamfAAD.migrator.plist" 2>/dev/null
    /usr/bin/su -l $mostRecentUser -c "launchctl bootstrap gui/$userID $LA_path" 2>/dev/null
}

### Call functions ###
jamfsoftware_settings
make_la
