-- Add to WatchLater — one keystroke from Raycast: the page you are looking at
-- goes straight into the native WatchLater app (Mac + iPhone, via iCloud).
--
-- It asks Safari (or Chrome) for the front page's address and hands it to the
-- app through its own address, amswatchlater://add?url=… — the app reads the
-- title, picture and length itself. The app opens in the background, so you
-- stay where you are. The only permission it needs: reading Safari's address,
-- asked once by macOS.

on run
	set theURL to ""
	try
		if application "Safari" is running then
			tell application "Safari"
				if (count of windows) > 0 then set theURL to (URL of current tab of front window) as text
			end tell
		end if
	end try
	if theURL is "" or theURL is "missing value" then
		try
			if application "Google Chrome" is running then
				tell application "Google Chrome"
					if (count of windows) > 0 then set theURL to (URL of active tab of front window) as text
				end tell
			end if
		end try
	end if
	if theURL is "" or theURL is "missing value" or theURL does not start with "http" then
		display notification "No web page open in Safari or Chrome." with title "WatchLater"
		return
	end if

	-- The address rides inside another address, so every special character
	-- must be encoded — a YouTube link is full of ? & and =.
	set encoded to do shell script "/usr/bin/osascript -l JavaScript -e 'function run(a){return encodeURIComponent(a[0])}' " & quoted form of theURL
	do shell script "/usr/bin/open -g " & quoted form of ("amswatchlater://add?url=" & encoded)
	display notification "Saved to WatchLater" with title "WatchLater"
end run
